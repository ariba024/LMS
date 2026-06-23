"""
main.py — FastAPI server for production-grade attention monitoring.

Endpoints:
  GET  /           health check
  GET  /status     pipeline config + thresholds
  WS   /ws/detect  stream: send base64 JPEG → receive AttentionResult JSON

WebSocket protocol:
  Client → Server : base64-encoded JPEG string (text frame)
  Server → Client : JSON matching AttentionResult schema
"""

import asyncio
import base64
import logging
import os
from concurrent.futures import ThreadPoolExecutor
from contextlib import asynccontextmanager

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

import config
from detector.pipeline import AttentionPipeline, AttentionResult

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
log = logging.getLogger(__name__)

# ── App lifecycle ──────────────────────────────────────────────────────────────

pipeline: AttentionPipeline | None = None
executor: ThreadPoolExecutor | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global pipeline, executor
    log.info("Starting up — loading MediaPipe model…")
    pipeline = AttentionPipeline()
    # max_workers=1: pipeline uses VIDEO mode tracking which requires serial calls
    executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="detector")
    log.info("Ready.  WebSocket: ws://localhost:8001/ws/detect")
    yield
    log.info("Shutting down…")
    if pipeline:
        pipeline.close()
    if executor:
        executor.shutdown(wait=False)


app = FastAPI(
    title="Attention Detection API",
    description="Production-grade learner attention monitoring — MediaPipe + PnP + PERCLOS",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── REST ───────────────────────────────────────────────────────────────────────

@app.get("/health")
def root():
    return {"status": "ok", "message": "Attention Detection API v2 is running"}


@app.get("/status")
def status():
    return {
        "pipeline": "ready" if pipeline else "not initialised",
        "thresholds": {
            "head_yaw_warning_deg":    config.HEAD_YAW_WARNING_DEG,
            "head_yaw_away_deg":       config.HEAD_YAW_AWAY_DEG,
            "ear_closed":              config.EAR_CLOSED,
            "perclos_drowsy":          config.PERCLOS_DROWSY,
            "perclos_sleep":           config.PERCLOS_SLEEP,
            "look_away_warning_sec":   config.LOOK_AWAY_WARNING_SEC,
            "look_away_distracted_sec": config.LOOK_AWAY_DISTRACTED_SEC,
            "look_back_recover_sec":   config.LOOK_BACK_RECOVER_SEC,
        },
        "states": [
            "focused", "warning", "distracted",
            "drowsy", "sleeping",
            "no_face", "multiple_faces", "occluded", "low_confidence",
        ],
    }


# ── WebSocket ──────────────────────────────────────────────────────────────────

@app.websocket("/ws/detect")
async def detect_ws(websocket: WebSocket):
    await websocket.accept()
    client = websocket.client
    log.info("WS connected: %s", client)

    try:
        while True:
            raw = await websocket.receive_text()

            try:
                jpeg_bytes = base64.b64decode(raw)
            except Exception:
                await websocket.send_json({"error": "invalid base64"})
                continue

            loop   = asyncio.get_event_loop()
            result: AttentionResult = await loop.run_in_executor(
                executor, pipeline.analyze, jpeg_bytes
            )
            await websocket.send_json(result.to_dict())

    except WebSocketDisconnect:
        log.info("WS disconnected: %s", client)
    except Exception as exc:
        log.error("WS error (%s): %s", client, exc)


# ── Serve Flutter web build (mount LAST so API routes take priority) ───────────
_WEB_DIR = os.path.join(os.path.dirname(__file__), "web_build")
if os.path.isdir(_WEB_DIR):
    app.mount("/", StaticFiles(directory=_WEB_DIR, html=True), name="web")
    log.info("Serving Flutter web build from %s", _WEB_DIR)
