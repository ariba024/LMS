"""
download_model.py — Run this ONCE before starting the server.
Downloads the MediaPipe face_landmarker.task model (~29 MB).

Usage:
    python download_model.py
"""
import urllib.request
import os

MODEL_URL  = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
MODEL_PATH = "face_landmarker.task"

if os.path.exists(MODEL_PATH):
    print(f"Model already present: {MODEL_PATH}")
else:
    print(f"Downloading {MODEL_PATH} (~29 MB)...")
    urllib.request.urlretrieve(MODEL_URL, MODEL_PATH)
    print("Done.")
