"""
gaze.py — Iris-based gaze detection using MediaPipe's 478-landmark model.

The Face Landmarker task outputs 478 landmarks: 468 face + 10 iris.
  Left iris:  center=468, ring=469-472
  Right iris: center=473, ring=474-477

Iris position relative to the eye bounding box indicates where the person
is looking, independent of head rotation. This is a strong secondary signal:
  - Catches phone-checking (eyes down, head mostly forward)
  - Catches reading subtitles (eyes down-left)
  - Works even when head pose is uncertain (low reprojection confidence)

Signal: abs(iris_x - eye_center_x) / eye_width
  ~0.0-0.10 → iris centered → looking at screen
  ~0.25-0.40 → iris at edge → looking sideways / down

Combined rule (in pipeline.py):
  looking_away = head_pose_away OR (iris_looking_away AND face is detected)
"""

from dataclasses import dataclass
from typing import Optional

import numpy as np

from detector.face_mesh import FaceData

# ── Landmark indices ───────────────────────────────────────────────────────────

LEFT_IRIS_CTR  = 468    # left iris center  (person's left = image right)
RIGHT_IRIS_CTR = 473    # right iris center (person's right = image left)

# Horizontal eye corners
R_EYE_OUTER = 33    # person's right eye, temporal (far from nose, image-left)
R_EYE_INNER = 133   # person's right eye, nasal   (near nose, image-right)
L_EYE_OUTER = 362   # person's left eye,  temporal (far from nose, image-right)
L_EYE_INNER = 263   # person's left eye,  nasal   (near nose, image-left)

# Vertical eye bounds
R_EYE_TOP    = 159
R_EYE_BOTTOM = 145
L_EYE_TOP    = 386
L_EYE_BOTTOM = 374

# Thresholds
_SIDEWAYS_OFFSET = 0.28   # |iris_x - eye_center| / eye_width  →  looking sideways
_DOWN_RATIO      = 0.68   # iris_y / eye_height                →  looking down


@dataclass
class GazeResult:
    left_h_offset:    float   # abs horizontal offset left eye (0=centered, 0.5=edge)
    right_h_offset:   float
    left_v_ratio:     float   # vertical ratio left eye (0=top, 1=bottom)
    right_v_ratio:    float
    avg_h_offset:     float   # mean of both eyes
    avg_v_ratio:      float
    looking_sideways: bool
    looking_down:     bool
    looking_away:     bool    # sideways OR down


class IrisGazeDetector:
    """
    Compute iris gaze from 478-landmark face mesh.
    Falls back gracefully if iris landmarks are absent (< 478 pts).
    """

    def __init__(
        self,
        sideways_offset: float = _SIDEWAYS_OFFSET,
        down_ratio:      float = _DOWN_RATIO,
    ):
        self._sw   = sideways_offset
        self._down = down_ratio

    def compute(self, face: FaceData) -> Optional[GazeResult]:
        """Returns None when iris landmarks are unavailable."""
        if len(face.landmarks_px) < 478:
            return None

        lm = face.landmarks_px   # (478, 2)

        lh = self._h_offset(lm, LEFT_IRIS_CTR,  L_EYE_OUTER, L_EYE_INNER)
        rh = self._h_offset(lm, RIGHT_IRIS_CTR, R_EYE_OUTER, R_EYE_INNER)
        lv = self._v_ratio(lm,  LEFT_IRIS_CTR,  L_EYE_TOP, L_EYE_BOTTOM)
        rv = self._v_ratio(lm,  RIGHT_IRIS_CTR, R_EYE_TOP, R_EYE_BOTTOM)

        avg_h = (lh + rh) / 2.0
        avg_v = (lv + rv) / 2.0

        sideways = avg_h > self._sw
        down     = avg_v > self._down

        return GazeResult(
            left_h_offset=round(lh, 3),
            right_h_offset=round(rh, 3),
            left_v_ratio=round(lv, 3),
            right_v_ratio=round(rv, 3),
            avg_h_offset=round(avg_h, 3),
            avg_v_ratio=round(avg_v, 3),
            looking_sideways=sideways,
            looking_down=down,
            looking_away=sideways or down,
        )

    # ── Internal ──────────────────────────────────────────────────────────────

    @staticmethod
    def _h_offset(lm, iris_idx, outer_idx, inner_idx) -> float:
        """Abs horizontal offset of iris from eye centre, normalised to eye width."""
        iris_x  = lm[iris_idx,  0]
        outer_x = lm[outer_idx, 0]
        inner_x = lm[inner_idx, 0]
        center  = (outer_x + inner_x) / 2.0
        width   = abs(inner_x - outer_x) + 1.0
        return float(abs(iris_x - center) / width)

    @staticmethod
    def _v_ratio(lm, iris_idx, top_idx, bot_idx) -> float:
        """Vertical position of iris within the eye (0=top edge, 1=bottom edge)."""
        iris_y = lm[iris_idx, 1]
        top_y  = lm[top_idx,  1]
        bot_y  = lm[bot_idx,  1]
        height = abs(bot_y - top_y) + 1.0
        return float((iris_y - top_y) / height)
