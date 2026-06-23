# attention_backend/Dockerfile
#
# NOTE: This file is no longer the primary deployment path.
#
# As of 2026-06-23, the attention detection service is merged into the main
# LMS backend. The WebSocket runs at /ws/detect on port 8000, served by the
# main Dockerfile at the project root.
#
# This file is kept for reference only. Use the root Dockerfile for all builds.
# The root Dockerfile already handles:
#   - Copying attention_backend/ into the image
#   - Downloading face_landmarker.task at build time
#   - Installing mediapipe via requirements.txt

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

RUN python download_model.py

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001", "--workers", "1"]
