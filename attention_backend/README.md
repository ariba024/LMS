# Attention Backend

FastAPI + MediaPipe attention detection service used by the LMS lesson player.

## Setup

```bash
# Create venv OUTSIDE OneDrive (OneDrive sync deletes pip files)
python -m venv C:\monitoring_venv
C:\monitoring_venv\Scripts\activate

pip install -r requirements.txt

# Download the MediaPipe face landmarker model (~30 MB)
python download_model.py
```

## Run

```bash
cd attention_backend
C:\monitoring_venv\Scripts\python.exe -m uvicorn main:app --host 0.0.0.0 --port 8001
```

Backend listens at `http://localhost:8001`.  
WebSocket endpoint: `ws://localhost:8001/ws/detect`

## Frontend connection

The Flutter frontend connects via `FOCUS_WS_URL` dart-define:

```bash
flutter run -d chrome --dart-define=FOCUS_WS_URL=ws://localhost:8001/ws/detect
```

For a public URL (Cloudflare Tunnel):
```bash
winget install --id Cloudflare.cloudflared
cloudflared tunnel --url http://localhost:8001
# Use the printed URL, e.g. wss://abc-def.trycloudflare.com/ws/detect
```
