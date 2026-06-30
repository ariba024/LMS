param([int]$ApiPort = 8000, [int]$WebPort = 5500)

$root = $PSScriptRoot

Write-Host ""
Write-Host "Arresto LMS - Dev Start" -ForegroundColor Cyan
Write-Host "  Backend   http://localhost:$ApiPort" -ForegroundColor Green
Write-Host "  API docs  http://localhost:$ApiPort/docs" -ForegroundColor Gray
Write-Host "  Frontend  http://localhost:$WebPort" -ForegroundColor Green
Write-Host "  Attention ws://localhost:$ApiPort/ws/detect" -ForegroundColor Green
Write-Host ""

# ── 1. LMS backend (includes attention WebSocket on /ws/detect) ────────────────
Start-Process powershell -ArgumentList "-NoExit", "-Command", `
    "cd '$root'; C:\lms_venv\Scripts\uvicorn.exe api.main:app --host 0.0.0.0 --port $ApiPort --reload" `
    -WindowStyle Normal

Start-Sleep -Milliseconds 800

# ── 2. Flutter dev server ──────────────────────────────────────────────────────
# Default JS renderer (no --wasm flag) is required for video_player to be
# visible on web — Skwasm/WASM renderer covers <video> with its canvas layer.
Start-Process powershell -ArgumentList "-NoExit", "-Command", `
    "cd '$root\frontend-lms'; flutter run -d web-server --web-port $WebPort --web-hostname localhost --dart-define=API_BASE_URL=http://localhost:$ApiPort --dart-define=FOCUS_WS_URL=ws://localhost:$ApiPort/ws/detect" `
    -WindowStyle Normal

Write-Host "Two windows opened." -ForegroundColor Cyan
Write-Host "Wait ~20s then open http://localhost:$WebPort" -ForegroundColor White
Write-Host ""
