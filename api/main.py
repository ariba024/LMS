"""
api/main.py -- FastAPI application entry point.

Startup sequence (lifespan)
---------------------------
1. Initialise VectorStore (opens ChromaDB on disk -- fast)
2. Initialise Embedder (lazy -- model loads on first request)
3. Initialise IngestionPipeline (wraps extractors + chunker + embedder + store)
4. Initialise RetrievalPipeline (bge-m3 + BM25 + reranker + Haiku intent detection)
5. Initialise ProgressTracker (SQLite-backed learner analytics)
6. Initialise Transcriber (optional, requires SARVAM_API_KEY)
7. Initialise TTSEngine (optional, requires OPENAI_API_KEY)

All objects are stored in app.state and injected into routes via FastAPI
dependency injection (see dependencies.py).
"""

import logging
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from api.config import settings
from api.routers import documents, chat, courses, tutor, progress, audio, voice, video, questions, tts, assessments
from api.routers import profile, learners, analytics, notifications, gamification
from api.routers import attention
from api.routers import attention_events as attention_events_router
from api.routers import auth as auth_router
from api.routers import tickets as tickets_router
from api.routers import admin_users as admin_users_router
from api.routers import certificates as certs_router
from api.schemas import HealthResponse

# -- Logging setup --------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("arresto.api")


# -- Lifespan -------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize and clean up shared resources."""
    from modules.content_ingestion.embedder     import Embedder
    from modules.content_ingestion.vector_store import VectorStore
    from modules.content_ingestion.chunker      import Chunker
    from modules.content_ingestion.pipeline     import IngestionPipeline

    logger.info("Initialising Arresto LMS API ...")

    # Database: create all SQLAlchemy-managed tables in lms.db
    from api.db import init_db
    init_db()

    # JobStore reads existing jobs from DB — must run after init_db()
    from api.dependencies import job_store
    job_store.load()

    if settings.jwt_secret_key == "CHANGE_ME_USE_A_LONG_RANDOM_SECRET_IN_PRODUCTION":
        logger.warning(
            "JWT_SECRET_KEY is the default placeholder — tokens are NOT secure. "
            "Set a real secret in .env before deploying to production."
        )

    # Seed default admin account (no-op if already exists)
    from api.db import SessionLocal
    from api.models.users import UserRow
    from api.auth import hash_password as _hash
    with SessionLocal() as _db:
        if not _db.query(UserRow).filter(UserRow.email == "admin@arresto.in").first():
            _db.add(UserRow(
                email="admin@arresto.in",
                password_hash=_hash("Admin@123"),
                role="admin",
                display_name="Admin",
            ))
            _db.commit()
            logger.info("Seeded default admin: admin@arresto.in / Admin@123 — change immediately!")

    # GPU initialisation — detect CUDA early so all models land on the same device
    try:
        import torch
        if torch.cuda.is_available():
            gpu_name  = torch.cuda.get_device_name(0)
            vram_gb   = torch.cuda.get_device_properties(0).total_memory / 1024**3
            logger.info("CUDA available — %s (%.1f GB VRAM)", gpu_name, vram_gb)
            # Reserve the CUDA context now so the first model load isn't slow
            torch.cuda.init()
        else:
            logger.info("CUDA not available — using CPU for all ML models")
    except ImportError:
        logger.info("torch not installed — ML models will use CPU")

    vs = VectorStore(persist_dir=str(settings.chroma_db_dir))
    em = Embedder()
    em._load()  # warm up on GPU at startup instead of on first request

    captioner = None
    if settings.enable_captioning:
        from modules.content_ingestion.captioner import ImageCaptioner
        captioner = ImageCaptioner()
        print("[startup] BLIP-2 captioner enabled (will load on first image).")

    pipeline = IngestionPipeline(
        extract_images=settings.enable_captioning,
        enable_ocr=settings.enable_ocr,
        ocr_lang=settings.ocr_lang,
        captioner=captioner,
        chunker=Chunker(),
        embedder=em,
        vector_store=vs,
    )
    if settings.enable_ocr:
        print(f"[startup] OCR enabled (lang={settings.ocr_lang})")

    app.state.embedder     = em
    app.state.vector_store = vs
    app.state.pipeline     = pipeline

    # Transcriber — Sarvam AI speech-to-text (optional, requires SARVAM_API_KEY)
    app.state.transcriber = None
    if settings.sarvam_api_key:
        try:
            from modules.voice import Transcriber
            app.state.transcriber = Transcriber(
                api_key=settings.sarvam_api_key,
                language=settings.sarvam_language,
            )
            logger.info("Transcriber (Sarvam STT) ready (language=%s)", settings.sarvam_language)
        except Exception as exc:
            logger.warning("Transcriber failed to init: %s", exc)

    # TTS engine — Sarvam Bulbul-v3 (preferred) or OpenAI (fallback)
    app.state.tts_engine = None
    if settings.sarvam_api_key:
        try:
            from modules.video.generators.sarvam_tts import SarvamTTSEngine
            tts_lang = settings.sarvam_language.lower()
            app.state.tts_engine = SarvamTTSEngine(lang=tts_lang)
            logger.info("TTS engine ready (Sarvam Bulbul-v3, lang=%s)", tts_lang)
        except Exception as exc:
            logger.warning("Sarvam TTS engine failed to init: %s", exc)
    elif settings.openai_api_key:
        try:
            from modules.tts import TTSEngine
            app.state.tts_engine = TTSEngine(
                api_key=settings.openai_api_key,
                model=settings.tts_model,
                voice=settings.tts_voice,
            )
            logger.info("TTS engine ready (OpenAI %s, voice=%s)", settings.tts_model, settings.tts_voice)
        except ImportError:
            logger.warning("openai package not installed — run: pip install openai>=1.0.0")
        except Exception as exc:
            logger.warning("TTS engine failed to init: %s", exc)

    # Progress tracker — shares the ORM engine so there is only one connection pool to lms.db
    from api.db import engine as _orm_engine
    from modules.progress.tracker import ProgressTracker
    from modules.progress.store   import ProgressStore
    app.state.progress_tracker = ProgressTracker(store=ProgressStore(engine=_orm_engine))
    logger.info("Progress tracker initialised (shared ORM engine)")

    # Pre-warm OCR engine in the background so the first document upload
    # doesn't stall while EasyOCR downloads its language models (~150 MB).
    if settings.enable_ocr:
        import threading
        from modules.content_ingestion.ocr import OCREngine
        def _warm_ocr() -> None:
            try:
                OCREngine(settings.ocr_lang)._init()
                logger.info("OCR engine pre-warmed (lang=%s)", settings.ocr_lang)
            except Exception as exc:
                logger.warning("OCR pre-warm failed: %s", exc)
        threading.Thread(target=_warm_ocr, daemon=True, name="ocr-prewarm").start()

    app.state.retrieval_pipeline = None
    if settings.enable_retrieval_pipeline and settings.anthropic_api_key:
        try:
            from modules.retrieval.pipeline import RetrievalPipeline
            app.state.retrieval_pipeline = RetrievalPipeline(
                api_key=settings.anthropic_api_key,
                bge_db_dir=settings.chroma_db_dir_bge,
                enable_reranking=settings.enable_reranking,
                haiku_model=settings.haiku_model,
                top_candidates=30,
                top_final=8,
            )
        except Exception as exc:
            logger.warning("Retrieval pipeline failed to init: %s", exc)
            logger.warning("  Tutor will fall back to basic MiniLM retrieval.")
    elif not settings.enable_retrieval_pipeline:
        logger.info("Retrieval pipeline disabled (ENABLE_RETRIEVAL_PIPELINE=false)")
    else:
        logger.info("Retrieval pipeline skipped — ANTHROPIC_API_KEY not set")

    # Attention pipeline — optional, requires mediapipe + opencv
    attention.init(app.state)

    claude_status = "enabled" if settings.anthropic_api_key else "disabled (set ANTHROPIC_API_KEY)"
    rp_status     = "enabled" if app.state.retrieval_pipeline else "disabled"
    attn_status   = "enabled" if app.state.attention_pipeline else "disabled"
    logger.info(
        "Ready — %d chunks in DB | Claude: %s | Retrieval pipeline: %s | Attention: %s",
        vs.count(), claude_status, rp_status, attn_status,
    )

    yield  # <- server runs here

    attention.shutdown(app.state)
    logger.info("Arresto LMS API shutting down.")


# -- App ------------------------------------------------------------------------

app = FastAPI(
    title="Arresto LMS -- Content Ingestion API",
    description=(
        "Upload training documents (PDF/DOCX/PPTX), ask questions about them "
        "via RAG, and generate structured course scripts for PPT/audio/video pipelines."
    ),
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

_cors_origins = [o.strip() for o in settings.cors_origins.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def _request_logging(request: Request, call_next):
    """Log method, path, status, latency and a short request ID for every HTTP call."""
    req_id = uuid.uuid4().hex[:12]
    t0 = time.perf_counter()
    response = await call_next(request)
    ms = round((time.perf_counter() - t0) * 1000)
    logger.info(
        "%s %s → %d  %dms  rid=%s",
        request.method,
        request.url.path,
        response.status_code,
        ms,
        req_id,
    )
    response.headers["X-Request-ID"] = req_id
    return response

app.include_router(documents.router)
app.include_router(chat.router)
app.include_router(courses.router)
app.include_router(tutor.router)
app.include_router(progress.router)
app.include_router(audio.router)
app.include_router(voice.router)
app.include_router(video.router)
app.include_router(questions.router)
app.include_router(tts.router)
app.include_router(assessments.router)
app.include_router(profile.router)
app.include_router(learners.router)
app.include_router(analytics.router)
app.include_router(notifications.router)
app.include_router(attention.router)
app.include_router(attention_events_router.router)
app.include_router(gamification.router)
app.include_router(auth_router.router)
app.include_router(tickets_router.router)
app.include_router(admin_users_router.router)
app.include_router(certs_router.router)


# -- Global exception handler ---------------------------------------------------
# Catches any unhandled Python exception that escapes a route handler and returns
# a clean JSON 500 instead of leaking tracebacks to the client.

@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error. Please try again or contact support."},
    )


# -- Root & health --------------------------------------------------------------

@app.get("/api", tags=["Info"])
def root():
    return {
        "service": "Arresto LMS Content Ingestion API",
        "version": "1.0.0",
        "docs":    "/docs",
    }


@app.get("/health", response_model=HealthResponse, tags=["Info"])
def health():
    """System health -- shows DB chunk count, available sources, feature flags."""
    vs = app.state.vector_store
    return HealthResponse(
        status="ok",
        chunks_in_db=vs.count(),
        documents=vs.list_sources(),
        claude_enabled=bool(settings.anthropic_api_key),
        captioning_on=settings.enable_captioning,
        ocr_enabled=settings.enable_ocr,
    )


# -- Flutter web (must be last — StaticFiles("/") is a catch-all) ---------------
_FLUTTER_WEB = (
    Path(__file__).resolve().parent.parent
    / "frontend-lms" / "build" / "web"
)

_NO_CACHE = {"Cache-Control": "no-store, no-cache, must-revalidate"}

# Serve critical Flutter JS files with no-cache headers so rebuilds take effect
# immediately without requiring the user to hard-refresh the browser.
@app.get("/main.dart.js", include_in_schema=False)
def _serve_main_js():
    return FileResponse(str(_FLUTTER_WEB / "main.dart.js"),
                        headers=_NO_CACHE, media_type="application/javascript")

@app.get("/flutter_bootstrap.js", include_in_schema=False)
def _serve_bootstrap_js():
    return FileResponse(str(_FLUTTER_WEB / "flutter_bootstrap.js"),
                        headers=_NO_CACHE, media_type="application/javascript")

@app.get("/flutter_service_worker.js", include_in_schema=False)
def _serve_service_worker_js():
    return FileResponse(str(_FLUTTER_WEB / "flutter_service_worker.js"),
                        headers=_NO_CACHE, media_type="application/javascript")

if _FLUTTER_WEB.exists():
    app.mount(
        "/",
        StaticFiles(directory=str(_FLUTTER_WEB), html=True),
        name="flutter",
    )
