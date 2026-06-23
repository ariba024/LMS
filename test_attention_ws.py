"""
test_attention_ws.py — Test the attention detection WebSocket endpoint.

Usage:
    python test_attention_ws.py                    # synthetic blank frame (no face)
    python test_attention_ws.py path/to/face.jpg   # real face image
    python test_attention_ws.py --frames 10        # send 10 frames, show all results

The server must be running:  .venv\\Scripts\\uvicorn.exe api.main:app --port 8000
"""

import argparse
import asyncio
import base64
import io
import json
import sys

import numpy as np
from PIL import Image


WS_URL = "ws://localhost:8000/ws/detect"


def _make_blank_frame(width: int = 640, height: int = 480) -> bytes:
    """Create a plain grey JPEG — pipeline will return no_face, proving the WS works."""
    arr = np.full((height, width, 3), 128, dtype=np.uint8)
    img = Image.fromarray(arr, "RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


def _load_image(path: str) -> bytes:
    img = Image.open(path).convert("RGB")
    img.thumbnail((640, 480))
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


def _print_result(result: dict, frame_num: int) -> None:
    state = result.get("attention_state", "?")
    score = result.get("attention_score", 0.0)
    faces = result.get("face_count", 0)
    calib = result.get("calibrated", False)
    conf  = result.get("confidence", 0.0)
    err   = result.get("error", "")

    state_color = {
        "focused":        "\033[92m",   # green
        "warning":        "\033[93m",   # yellow
        "distracted":     "\033[91m",   # red
        "drowsy":         "\033[91m",
        "sleeping":       "\033[91m",
        "no_face":        "\033[90m",   # grey
        "multiple_faces": "\033[93m",
        "occluded":       "\033[93m",
        "low_confidence": "\033[90m",
    }.get(state, "\033[0m")
    reset = "\033[0m"

    print(f"Frame {frame_num:>3} │ "
          f"state={state_color}{state:<16}{reset} │ "
          f"score={score:.2f} │ "
          f"faces={faces} │ "
          f"conf={conf:.2f} │ "
          f"calibrated={calib}"
          + (f" │ ⚠ {err}" if err else ""))


async def run(image_path: str | None, num_frames: int) -> None:
    try:
        import websockets
    except ImportError:
        print("ERROR: websockets not installed. Run: pip install websockets")
        sys.exit(1)

    if image_path:
        try:
            jpeg_bytes = _load_image(image_path)
            print(f"Loaded image: {image_path}")
        except Exception as e:
            print(f"ERROR loading image: {e}")
            sys.exit(1)
    else:
        jpeg_bytes = _make_blank_frame()
        print("Using synthetic blank frame (no face expected — tests WS connectivity)")

    b64 = base64.b64encode(jpeg_bytes).decode()

    print(f"Connecting to {WS_URL} ...")
    try:
        async with websockets.connect(WS_URL, open_timeout=5) as ws:
            print(f"Connected. Sending {num_frames} frame(s)...\n")

            for i in range(1, num_frames + 1):
                await ws.send(b64)
                raw = await ws.recv()
                result = json.loads(raw)
                _print_result(result, i)

                if result.get("error") == "attention_unavailable":
                    print("\n⚠  Pipeline not loaded — check backend startup log for:")
                    print('   "Attention pipeline disabled — mediapipe not installed"')
                    print("   Fix: .venv\\Scripts\\pip install mediapipe")
                    break

                if i < num_frames:
                    await asyncio.sleep(0.1)

    except OSError:
        print(f"\nERROR: Could not connect to {WS_URL}")
        print("Make sure the backend is running:  .venv\\Scripts\\uvicorn.exe api.main:app --port 8000")
        sys.exit(1)

    print("\nDone.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test attention WebSocket endpoint")
    parser.add_argument("image", nargs="?", help="Path to a JPEG/PNG face image (optional)")
    parser.add_argument("--frames", type=int, default=3, help="Number of frames to send (default: 3)")
    args = parser.parse_args()

    asyncio.run(run(args.image, args.frames))
