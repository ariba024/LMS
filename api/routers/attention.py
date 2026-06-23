"""
api/routers/attention.py — Learner attention detection via WebSocket.

Receives base64-encoded JPEG camera frames from the Flutter lesson player,
runs them through the MediaPipe-based AttentionPipeline, and streams back
JSON attention results.

WebSocket protocol (same as standalone attention_backend):
  Client → Server : base64 JPEG string (text frame)
  Server → Client : AttentionResult JSON  {attention_state, attention_score, ...}

The pipeline is optional — if mediapipe is not installed the endpoint still
accepts connections but immediately returns {"attention_state": "focused"} so
the Flutter app degrades gracefully (video keeps playing, no overlay).
"""

import asyncio
import base64
import logging
import os
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["Attention"])
logger = logging.getLogger("arresto.attention")

# ---------------------------------------------------------------------------
# Path setup — attention_backend uses plain `import config` and
# `from detector.X import Y` (designed to run from its own directory).
# Adding it to sys.path lets those imports resolve from anywhere.
# ---------------------------------------------------------------------------
_ATTENTION_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "attention_backend")
)
if os.path.isdir(_ATTENTION_DIR) and _ATTENTION_DIR not in sys.path:
    sys.path.insert(0, _ATTENTION_DIR)


# ---------------------------------------------------------------------------
# Model auto-download
# ---------------------------------------------------------------------------

_MODEL_PATH = os.path.join(_ATTENTION_DIR, "face_landmarker.task")
_MODEL_URL  = (
    "https://storage.googleapis.com/mediapipe-models/"
    "face_landmarker/face_landmarker/float16/1/face_landmarker.task"
)


def _ensure_model() -> bool:
    """Download the MediaPipe model if missing. Returns True when the file is ready."""
    if os.path.exists(_MODEL_PATH):
        return True
    if not os.path.isdir(_ATTENTION_DIR):
        return False
    try:
        logger.info("Downloading MediaPipe face_landmarker.task (~29 MB) ...")
        urllib.request.urlretrieve(_MODEL_URL, _MODEL_PATH)
        logger.info("Model downloaded: %s", _MODEL_PATH)
        return True
    except Exception as exc:
        logger.warning("Model download failed: %s", exc)
        return False


# ---------------------------------------------------------------------------
# Lifecycle helpers — called from api/main.py lifespan
# ---------------------------------------------------------------------------

def init(app_state) -> None:
    """Load the attention pipeline into app.state. Safe to call if mediapipe is absent."""
    app_state.attention_pipeline = None
    app_state.attention_executor = None

    if not os.path.isdir(_ATTENTION_DIR):
        logger.info("Attention pipeline disabled — attention_backend/ directory not found")
        return

    if not _ensure_model():
        logger.warning("Attention pipeline disabled — model file unavailable")
        return

    try:
        from detector.pipeline import AttentionPipeline  # noqa: PLC0415
        app_state.attention_pipeline = AttentionPipeline()
        # max_workers=1: MediaPipe VIDEO mode requires serial frame calls
        app_state.attention_executor = ThreadPoolExecutor(
            max_workers=1, thread_name_prefix="attention"
        )
        logger.info("Attention pipeline ready (MediaPipe face mesh)")
    except ImportError:
        logger.info(
            "Attention pipeline disabled — mediapipe not installed. "
            "Run: pip install -r requirements.txt"
        )
    except Exception as exc:
        logger.warning("Attention pipeline failed to initialise: %s", exc)


def shutdown(app_state) -> None:
    """Release pipeline resources. Called from api/main.py lifespan on exit."""
    executor = getattr(app_state, "attention_executor", None)
    pipeline = getattr(app_state, "attention_pipeline", None)
    if executor:
        executor.shutdown(wait=False)
    if pipeline:
        pipeline.close()


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------

@router.websocket("/ws/detect")
async def detect_ws(websocket: WebSocket) -> None:
    pipeline = websocket.app.state.attention_pipeline
    executor = websocket.app.state.attention_executor

    await websocket.accept()

    # Graceful degradation: if pipeline not available, tell the client to
    # stay in "focused" state so the video never gets paused.
    if pipeline is None:
        await websocket.send_json({
            "attention_state": "focused",
            "error": "attention_unavailable",
        })
        await websocket.close()
        return

    logger.info("Attention WS connected: %s", websocket.client)

    try:
        while True:
            raw = await websocket.receive_text()

            try:
                jpeg_bytes = base64.b64decode(raw)
            except Exception:
                await websocket.send_json({
                    "attention_state": "focused",
                    "error": "invalid_base64",
                })
                continue

            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(executor, pipeline.analyze, jpeg_bytes)
            await websocket.send_json(result.to_dict())

    except WebSocketDisconnect:
        logger.info("Attention WS disconnected: %s", websocket.client)
    except Exception as exc:
        logger.error("Attention WS error (%s): %s", websocket.client, exc)
