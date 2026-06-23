"""
face_mesh.py — MediaPipe Face Landmarker wrapper.

Uses RunningMode.VIDEO so MediaPipe applies inter-frame temporal
tracking, improving landmark stability vs per-frame IMAGE mode.

Returns FaceData per detected face (pixel coords + visibility scores).
Supports up to max_faces simultaneous detections for multi-face detection.
"""

import os
import time
from dataclasses import dataclass, field
from typing import List, Optional

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision as mp_vision

MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "face_landmarker.task")


def _lm_score(lm) -> float:
    """Return presence/visibility score from a MediaPipe landmark, defaulting to 1.0.
    Face landmarks in the Tasks API have presence/visibility as Optional[float] = None."""
    for attr in ("presence", "visibility"):
        v = getattr(lm, attr, None)
        if v is not None:
            return float(v)
    return 1.0


@dataclass
class FaceData:
    """Landmarks + metadata for a single detected face."""
    landmarks_px:           np.ndarray   # (N, 2) float32 — pixel (x, y)
    landmarks_norm:         np.ndarray   # (N, 3) float32 — normalized (x, y, z)
    visibility:             np.ndarray   # (N,)   float32 — per-landmark visibility 0-1
    detection_confidence:   float        # mean visibility of key landmarks
    face_index:             int = 0


@dataclass
class MeshResult:
    faces:       List[FaceData] = field(default_factory=list)
    frame_w:     int = 0
    frame_h:     int = 0
    timestamp_ms: int = 0

    @property
    def face_count(self) -> int:
        return len(self.faces)

    @property
    def primary_face(self) -> Optional[FaceData]:
        """Largest / highest-confidence face."""
        return self.faces[0] if self.faces else None


class FaceMeshDetector:
    """
    Wraps MediaPipe FaceLandmarker in VIDEO mode.

    Design decision: VIDEO mode vs IMAGE mode.
    VIDEO mode maintains face-tracking state across frames, giving
    smoother landmark trajectories and better handling of brief occlusions.
    Requires strictly monotonic timestamps — we use time.monotonic().
    """

    def __init__(self, max_faces: int = 3):
        if not os.path.exists(MODEL_PATH):
            raise FileNotFoundError(
                f"Model not found: {MODEL_PATH}\n"
                "Run:  python download_model.py"
            )

        base_opts = mp_python.BaseOptions(model_asset_path=MODEL_PATH)
        opts = mp_vision.FaceLandmarkerOptions(
            base_options=base_opts,
            running_mode=mp_vision.RunningMode.VIDEO,
            num_faces=max_faces,
            min_face_detection_confidence=0.40,
            min_face_presence_confidence=0.40,
            min_tracking_confidence=0.40,
            output_face_blendshapes=False,
            output_facial_transformation_matrixes=False,
        )
        self._lm       = mp_vision.FaceLandmarker.create_from_options(opts)
        self._start_ms = int(time.monotonic() * 1000)

    def detect(self, jpeg_bytes: bytes) -> Optional[MeshResult]:
        """
        Decode JPEG bytes and run face landmark detection.
        Returns MeshResult (may have 0 faces). Returns None only on
        total decode failure (corrupt frame).
        """
        arr   = np.frombuffer(jpeg_bytes, dtype=np.uint8)
        frame = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if frame is None:
            return None

        h, w  = frame.shape[:2]
        rgb   = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        mp_img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
        ts_ms  = max(1, int(time.monotonic() * 1000) - self._start_ms)

        out    = self._lm.detect_for_video(mp_img, ts_ms)
        result = MeshResult(frame_w=w, frame_h=h, timestamp_ms=ts_ms)

        if not out.face_landmarks:
            return result

        for i, lms in enumerate(out.face_landmarks):
            pts_px   = np.array([[lm.x * w, lm.y * h] for lm in lms], dtype=np.float32)
            pts_norm = np.array([[lm.x, lm.y, lm.z]   for lm in lms], dtype=np.float32)
            vis      = np.array(
                [_lm_score(lm) for lm in lms],
                dtype=np.float32,
            )
            # Confidence = mean visibility of the 10 key eye/nose landmarks
            key_idx = [33, 133, 362, 263, 1, 4, 61, 291, 199, 152]
            conf    = float(np.mean(vis[key_idx]))

            result.faces.append(FaceData(
                landmarks_px=pts_px,
                landmarks_norm=pts_norm,
                visibility=vis,
                detection_confidence=conf,
                face_index=i,
            ))

        return result

    def close(self) -> None:
        self._lm.close()
