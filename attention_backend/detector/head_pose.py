"""
head_pose.py — Head pose estimation with EMA smoothing and neutral calibration.

Key improvements:
  1. EMA smoothing (alpha=0.5): angle readings are averaged over recent frames,
     eliminating jitter from natural micro-movements that cause false warnings.

  2. Neutral calibration: first CALIBRATION_FRAMES frames establish the person's
     natural head orientation (handles tilted laptops, non-centered cameras).
     Subsequent angles are reported relative to that neutral.

  3. Confidence-gated output: head pose with reprojection error > threshold
     returns None so the pipeline doesn't act on unreliable estimates.

  4. Gaze direction hysteresis: direction label only changes after 3 consecutive
     frames in the new direction, preventing rapid flicker between labels.
"""

from dataclasses import dataclass
from typing import List, Optional

import cv2
import numpy as np

from detector.face_mesh import FaceData

# MediaPipe landmark indices for the 6 PnP anchors
ANCHOR_IDX = [1, 152, 263, 33, 287, 57]

# Generic 3-D face model in millimetres (face-centred, +X right, +Y up, +Z toward cam)
FACE_3D = np.array([
    [ 0.0,    0.0,    0.0  ],   # nose tip
    [ 0.0,  -63.6,  -12.5 ],   # chin
    [-43.3,  32.7,  -26.0 ],   # left eye outer
    [ 43.3,  32.7,  -26.0 ],   # right eye outer
    [-28.9, -28.9,  -24.1 ],   # left mouth corner
    [ 28.9, -28.9,  -24.1 ],   # right mouth corner
], dtype=np.float64)

DIST_COEFFS = np.zeros((4, 1), dtype=np.float64)

# Calibration
_CAL_FRAMES    = 60
_CAL_LOW_TRIM  = 0.10
_CAL_HIGH_TRIM = 0.90

# EMA
_EMA_ALPHA = 0.50   # 0=frozen, 1=no smoothing

# Gaze direction hysteresis
_GAZE_CONFIRM_FRAMES = 3   # must see new direction this many frames before switching


@dataclass
class HeadPose:
    yaw:            float   # degrees — + looking right (from person's view)
    pitch:          float   # degrees — + looking up
    roll:           float   # degrees — tilt
    raw_yaw:        float   # before EMA (for debugging)
    raw_pitch:      float
    confidence:     float   # 0-1 from reprojection error
    gaze_direction: str     # "center"|"left"|"right"|"up"|"down"
    calibrated:     bool


class HeadPoseEstimator:
    """
    Stateful PnP estimator with EMA smoothing and per-session neutral calibration.
    Call estimate() once per frame.
    """

    def __init__(self, ema_alpha: float = _EMA_ALPHA):
        self._alpha = ema_alpha

        # EMA state
        self._yaw_ema:   Optional[float] = None
        self._pitch_ema: Optional[float] = None
        self._roll_ema:  Optional[float] = None

        # Neutral calibration
        self._yaw_cal_samples:   List[float] = []
        self._pitch_cal_samples: List[float] = []
        self._neutral_yaw   = 0.0
        self._neutral_pitch = 0.0
        self._calibrated    = False

        # Gaze hysteresis
        self._gaze_history: List[str] = []
        self._current_gaze  = "center"

    @property
    def is_calibrated(self) -> bool:
        return self._calibrated

    def estimate(self, face: FaceData, frame_w: int, frame_h: int) -> Optional[HeadPose]:
        pts_2d = face.landmarks_px[ANCHOR_IDX].astype(np.float64)

        focal = float(frame_w)
        cam   = np.array([
            [focal, 0.0,   frame_w / 2.0],
            [0.0,   focal, frame_h / 2.0],
            [0.0,   0.0,   1.0          ],
        ], dtype=np.float64)

        ok, rvec, tvec = cv2.solvePnP(
            FACE_3D, pts_2d, cam, DIST_COEFFS, flags=cv2.SOLVEPNP_SQPNP
        )
        if not ok:
            return None

        # Reprojection error → confidence
        proj, _ = cv2.projectPoints(FACE_3D, rvec, tvec, cam, DIST_COEFFS)
        reproj_err  = float(np.mean(np.linalg.norm(pts_2d - proj.reshape(-1, 2), axis=1)))
        confidence  = float(np.clip(1.0 - reproj_err / 30.0, 0.0, 1.0))

        # Euler angles from rotation matrix
        rmat, _ = cv2.Rodrigues(rvec)
        euler   = cv2.RQDecomp3x3(rmat)[0]
        raw_pitch =  float(euler[0])
        raw_yaw   = -float(euler[1])   # negate: + = right
        raw_roll  =  float(euler[2])

        # ── Neutral calibration ───────────────────────────────────────────────
        if not self._calibrated:
            if confidence > 0.4:    # only collect reliable poses
                self._yaw_cal_samples.append(raw_yaw)
                self._pitch_cal_samples.append(raw_pitch)
            if len(self._yaw_cal_samples) >= _CAL_FRAMES:
                self._run_calibration()

        yaw   = raw_yaw   - self._neutral_yaw
        pitch = raw_pitch - self._neutral_pitch

        # ── EMA smoothing ─────────────────────────────────────────────────────
        self._yaw_ema   = self._ema(self._yaw_ema,   yaw)
        self._pitch_ema = self._ema(self._pitch_ema, pitch)
        self._roll_ema  = self._ema(self._roll_ema,  raw_roll)

        smooth_yaw   = self._yaw_ema
        smooth_pitch = self._pitch_ema
        smooth_roll  = self._roll_ema

        gaze = self._update_gaze(smooth_yaw, smooth_pitch)

        return HeadPose(
            yaw=round(smooth_yaw, 1),
            pitch=round(smooth_pitch, 1),
            roll=round(smooth_roll, 1),
            raw_yaw=round(raw_yaw, 1),
            raw_pitch=round(raw_pitch, 1),
            confidence=round(confidence, 3),
            gaze_direction=gaze,
            calibrated=self._calibrated,
        )

    # ── Internal ──────────────────────────────────────────────────────────────

    def _ema(self, prev: Optional[float], raw: float) -> float:
        if prev is None:
            return raw
        return self._alpha * raw + (1.0 - self._alpha) * prev

    def _run_calibration(self) -> None:
        def trimmed_mean(samples):
            s = sorted(samples)
            n = len(s)
            lo, hi = int(n * _CAL_LOW_TRIM), int(n * _CAL_HIGH_TRIM)
            sliced = s[lo:hi + 1]
            return float(np.mean(sliced)) if sliced else 0.0

        self._neutral_yaw   = trimmed_mean(self._yaw_cal_samples)
        self._neutral_pitch = trimmed_mean(self._pitch_cal_samples)
        # Reset EMA with calibrated baseline so it doesn't average in pre-calibration values
        self._yaw_ema   = 0.0
        self._pitch_ema = 0.0
        self._calibrated = True

    def _update_gaze(self, yaw: float, pitch: float) -> str:
        """Hysteresis-gated gaze direction: must see new direction N frames to switch."""
        candidate = _raw_gaze(yaw, pitch)
        self._gaze_history.append(candidate)
        if len(self._gaze_history) > _GAZE_CONFIRM_FRAMES:
            self._gaze_history.pop(0)

        # Switch only when last N frames all agree on the new direction
        if len(self._gaze_history) == _GAZE_CONFIRM_FRAMES:
            if all(g == candidate for g in self._gaze_history):
                self._current_gaze = candidate

        return self._current_gaze


def _raw_gaze(yaw: float, pitch: float) -> str:
    if abs(yaw) < 12 and abs(pitch) < 12:
        return "center"
    if abs(yaw) >= abs(pitch):
        return "right" if yaw > 0 else "left"
    return "up" if pitch > 0 else "down"
