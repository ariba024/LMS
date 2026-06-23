# Attention Backend

> **Merged into the main LMS backend as of 2026-06-23.**
>
> The WebSocket endpoint now runs at `ws://localhost:8000/ws/detect` — same
> port as the rest of the API. You no longer need to run this as a separate
> service or maintain a separate venv.
>
> The standalone files here (main.py, Dockerfile, requirements.txt) are kept
> for reference. The active code path is `api/routers/attention.py`.

---

## How it works now

The main LMS backend (`api/main.py`) loads the `AttentionPipeline` at startup
and serves the WebSocket at `/ws/detect`.

The `detector/` package and `config.py` in this folder are imported directly
by `api/routers/attention.py` via a `sys.path` addition — no code was changed
inside this folder.

## One-time local setup

```powershell
# From the LMS root folder — installs mediapipe along with all other deps
pip install -r requirements.txt
```

The MediaPipe face landmark model (~29 MB) is downloaded automatically the
first time the backend starts if the file is not present. No separate step needed.

After this, `.\start.ps1` starts everything. The backend log will show:
```
Downloading MediaPipe face_landmarker.task (~29 MB) ...   ← first run only
Model downloaded: .../attention_backend/face_landmarker.task
Attention pipeline ready (MediaPipe face mesh)
```

## WebSocket protocol

```
Client → Server : base64-encoded JPEG string (text frame, sent every 800 ms)
Server → Client : JSON  { attention_state, attention_score, face_count, ... }
```

Endpoint: `ws://localhost:8000/ws/detect`

## Attention states

| State | Meaning |
|---|---|
| `focused` | Learner is looking at screen |
| `warning` | Head turned >30° or drowsy signal — 2 s grace period |
| `distracted` | Away >5 s — Flutter pauses video |
| `drowsy` | PERCLOS >15% over 30 s window |
| `sleeping` | Eyes closed continuously >2.5 s |
| `no_face` | No face detected in frame |
| `multiple_faces` | More than one face |
| `occluded` | Face detected but landmarks obscured |
| `low_confidence` | Pose estimate below confidence threshold |

## Thresholds (edit `config.py` to tune)

| Threshold | Default | Meaning |
|---|---|---|
| `HEAD_YAW_WARNING_DEG` | 30° | Start warning |
| `HEAD_YAW_AWAY_DEG` | 45° | Clearly looking away |
| `LOOK_AWAY_WARNING_SEC` | 2 s | Away → WARNING |
| `LOOK_AWAY_DISTRACTED_SEC` | 5 s | Away → DISTRACTED |
| `LOOK_BACK_RECOVER_SEC` | 3 s | Must look back this long to recover |
| `PERCLOS_DROWSY` | 15% | Drowsy threshold |
| `PERCLOS_SLEEP` | 40% | Sleeping threshold |
