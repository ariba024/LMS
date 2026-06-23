"""
ear.py — Eye Aspect Ratio (EAR) with per-person calibration and temporal smoothing.

Key improvements over fixed-threshold EAR:
  1. Adaptive calibration: first CALIBRATION_FRAMES frames establish each person's
     baseline open-eye EAR, then thresholds are set relative to that baseline.
     Handles people with naturally narrow eyes (EAR 0.15–0.18) or wide eyes (0.28+).

  2. Rolling average smoothing (EAR_SMOOTH_FRAMES=3): a single noisy frame no longer
     triggers closed-eye detection — closure must be sustained across multiple frames.

  3. Proper hysteresis: uses t_open (higher) to reopen from closed state, preventing
     rapid oscillation at the threshold boundary.

  4. Clamped output: EAR is capped at 5.0 to prevent numerical outliers from
     saturating downstream metrics when landmark positions are corrupted.
"""

from collections import deque
from dataclasses import dataclass
from typing import List, Optional

import numpy as np

from detector.face_mesh import FaceData

# 6 landmark indices per eye, ordered P0..P5 (Soukupová & Čech 2016)
LEFT_EYE  = [362, 385, 387, 263, 373, 380]
RIGHT_EYE = [ 33, 160, 158, 133, 153, 144]

# Calibration constants
_CAL_FRAMES       = 60     # ~4 s at 15 fps
_CAL_LOW_TRIM     = 0.20   # discard bottom 20% (blinks during calibration)
_CAL_HIGH_TRIM    = 0.95   # discard top 5% (outliers)
_CAL_CLOSED_RATIO = 0.75   # threshold = baseline * this
_CAL_OPEN_RATIO   = 0.85


@dataclass
class EARResult:
    left_ear:     float
    right_ear:    float
    avg_ear:      float
    smoothed_ear: float    # rolling-average EAR used for decisions
    left_closed:  bool
    right_closed: bool
    eyes_closed:  bool
    in_blink:     bool
    closed_frames: int
    confidence:   float
    calibrated:   bool     # True once per-person baseline is established


def _ear(pts: np.ndarray) -> float:
    A = float(np.linalg.norm(pts[1] - pts[5]))
    B = float(np.linalg.norm(pts[2] - pts[4]))
    C = float(np.linalg.norm(pts[0] - pts[3])) + 1e-6
    return min((A + B) / (2.0 * C), 5.0)   # capped to prevent outlier saturation


class EARDetector:
    """
    Stateful EAR detector with per-person calibration.

    During the first CALIBRATION_FRAMES frames the detector collects open-eye
    EAR samples.  After calibration it sets:
        closed_threshold = baseline * 0.75
        open_threshold   = baseline * 0.85
    which are person-specific and far more reliable than fixed values.
    """

    def __init__(
        self,
        closed_threshold: float = 0.20,
        open_threshold:   float = 0.25,
        blink_max_frames: int   = 8,
        smooth_frames:    int   = 3,
    ):
        self._t_close_default = closed_threshold
        self._t_open_default  = open_threshold
        self._t_close         = closed_threshold
        self._t_open          = open_threshold
        self._blink_max       = blink_max_frames

        self._closed_frames = 0
        self._was_closed    = False

        # Rolling average for noise suppression
        self._ear_buf: deque = deque(maxlen=smooth_frames)

        # Calibration state
        self._cal_samples: List[float] = []
        self._calibrated  = False

    @property
    def is_calibrated(self) -> bool:
        return self._calibrated

    @property
    def thresholds(self):
        return self._t_close, self._t_open

    def compute(self, face: FaceData) -> EARResult:
        lpts = face.landmarks_px[LEFT_EYE]
        rpts = face.landmarks_px[RIGHT_EYE]

        l_ear = _ear(lpts)
        r_ear = _ear(rpts)
        avg   = (l_ear + r_ear) / 2.0

        # ── Smoothing ────────────────────────────────────────────────────────
        self._ear_buf.append(avg)
        smoothed = float(np.mean(self._ear_buf))

        # ── Calibration ──────────────────────────────────────────────────────
        if not self._calibrated:
            # Only collect samples when eyes are likely open (EAR above default closed threshold)
            if avg > self._t_close_default:
                self._cal_samples.append(avg)
            if len(self._cal_samples) >= _CAL_FRAMES:
                self._run_calibration()

        # ── Hysteresis eye-closure decision (uses smoothed EAR) ─────────────
        # Opening is harder than closing — prevents flicker at the boundary.
        if self._was_closed:
            eyes_closed = smoothed < self._t_open   # must exceed open threshold to reopen
        else:
            eyes_closed = smoothed < self._t_close  # close at lower threshold

        # Per-eye state (uses raw for individual eye reporting)
        l_closed = l_ear < self._t_close
        r_closed = r_ear < self._t_close

        if eyes_closed:
            self._closed_frames += 1
        else:
            self._closed_frames = 0

        in_blink = eyes_closed and (1 <= self._closed_frames <= self._blink_max)
        self._was_closed = eyes_closed

        # ── Confidence from eye-landmark visibility ───────────────────────────
        all_eye_idx = LEFT_EYE + RIGHT_EYE
        eye_vis = face.visibility[all_eye_idx]
        conf    = float(np.mean(eye_vis)) if len(eye_vis) > 0 else 0.5

        return EARResult(
            left_ear=round(l_ear, 3),
            right_ear=round(r_ear, 3),
            avg_ear=round(avg, 3),
            smoothed_ear=round(smoothed, 3),
            left_closed=l_closed,
            right_closed=r_closed,
            eyes_closed=eyes_closed,
            in_blink=in_blink,
            closed_frames=self._closed_frames,
            confidence=round(conf, 3),
            calibrated=self._calibrated,
        )

    # ── Internal ──────────────────────────────────────────────────────────────

    def _run_calibration(self) -> None:
        samples = sorted(self._cal_samples)
        n = len(samples)
        lo = int(n * _CAL_LOW_TRIM)
        hi = int(n * _CAL_HIGH_TRIM)
        trimmed = samples[lo:hi + 1]
        if trimmed:
            baseline = float(np.mean(trimmed))
            # Clamp to sane absolute range regardless of baseline
            self._t_close = float(np.clip(baseline * _CAL_CLOSED_RATIO, 0.12, 0.22))
            self._t_open  = float(np.clip(baseline * _CAL_OPEN_RATIO,   0.15, 0.26))
        self._calibrated = True
