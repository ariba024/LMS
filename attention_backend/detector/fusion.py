"""
fusion.py — Confidence aggregation and attention scoring.

Key fixes:
  1. EMA resets on temporal state change — prevents score lag when recovering
     from distraction (was: blended old bad score into new good score for ~3 s).
  2. Head pose penalty aligned to config thresholds — penalty curve now starts
     ramping at WARNING threshold, maxes at AWAY threshold.
  3. Flat penalty removed for head pose failure — no longer penalises every
     frame where pose is uncertain (transient detection gaps are common).
"""

from dataclasses import dataclass
from typing import Optional, List

import config
from detector.ear import EARResult
from detector.head_pose import HeadPose
from detector.perclos import PerclosResult
from detector.temporal import AttentionState, TemporalState


@dataclass
class FusionResult:
    attention_score:  float
    focus_state:      str          # "focused" | "warning" | "distracted"
    drowsiness_score: float
    confidence:       float
    reasons:          List[str]


_STATE_PENALTY = {
    AttentionState.FOCUSED:        0,
    AttentionState.WARNING:        12,
    AttentionState.DISTRACTED:     35,
    AttentionState.DROWSY:         20,
    AttentionState.SLEEPING:       55,
    AttentionState.NO_FACE:        28,
    AttentionState.MULTIPLE_FACES:  8,
    AttentionState.OCCLUDED:       18,
    AttentionState.LOW_CONFIDENCE: 12,
}

_FOCUS_STATE_MAP = {
    AttentionState.FOCUSED:        "focused",
    AttentionState.WARNING:        "warning",
    AttentionState.DISTRACTED:     "distracted",
    AttentionState.DROWSY:         "warning",
    AttentionState.SLEEPING:       "distracted",
    AttentionState.NO_FACE:        "distracted",
    AttentionState.MULTIPLE_FACES: "warning",
    AttentionState.OCCLUDED:       "warning",
    AttentionState.LOW_CONFIDENCE: "warning",
}


class ConfidenceFusion:

    def __init__(self, smoothing_frames: int = 8):
        alpha = 2.0 / (smoothing_frames + 1)
        self._alpha              = alpha
        self._ema_attention:  Optional[float] = None
        self._ema_drowsiness: Optional[float] = None
        self._prev_state: Optional[AttentionState] = None

    def fuse(
        self,
        temporal:   TemporalState,
        head_pose:  Optional[HeadPose],
        ear:        Optional[EARResult],
        perclos:    PerclosResult,
        face_count: int,
    ) -> FusionResult:
        reasons: List[str] = []

        # ── Confidence ────────────────────────────────────────────────────────
        hp_conf   = head_pose.confidence if head_pose else 0.0
        ear_conf  = ear.confidence       if ear       else 0.0
        face_conf = 1.0 if face_count == 1 else (0.2 if face_count > 1 else 0.0)
        confidence = round(0.40 * hp_conf + 0.35 * ear_conf + 0.25 * face_conf, 3)

        # ── Attention score ───────────────────────────────────────────────────
        score = 100.0

        # Head pose penalties — ramped from WARNING_DEG to AWAY_DEG
        if head_pose and head_pose.confidence >= config.HEAD_POSE_MIN_CONFIDENCE:
            yaw_warn  = config.HEAD_YAW_WARNING_DEG
            yaw_away  = config.HEAD_YAW_AWAY_DEG
            pit_warn  = config.HEAD_PITCH_WARNING_DEG
            pit_away  = config.HEAD_PITCH_AWAY_DEG

            yaw_abs = abs(head_pose.yaw)
            pit_abs = abs(head_pose.pitch)

            # Ramp: 0 penalty at warning threshold, max at away threshold
            yaw_ramp = max(0.0, (yaw_abs - yaw_warn) / max(yaw_away - yaw_warn, 1.0))
            pit_ramp = max(0.0, (pit_abs - pit_warn) / max(pit_away - pit_warn, 1.0))

            score -= min(yaw_ramp, 1.0) * 25.0
            score -= min(pit_ramp, 1.0) * 12.0

            if yaw_abs > yaw_warn:
                reasons.append(
                    f"Head {'right' if head_pose.yaw > 0 else 'left'} {yaw_abs:.0f}°"
                )
            if pit_abs > pit_warn:
                reasons.append(
                    f"Head {'up' if head_pose.pitch > 0 else 'down'} {pit_abs:.0f}°"
                )
        # No penalty when head pose is absent/uncertain — avoid punishing transient failures

        # EAR / eye closure
        if ear:
            ear_val = ear.smoothed_ear if hasattr(ear, "smoothed_ear") else ear.avg_ear
            if ear.eyes_closed:
                score -= 28.0
                if ear.closed_frames > 4:
                    reasons.append(f"Eyes closed {ear.closed_frames} frames")
            elif ear_val < 0.22:
                score -= 10.0
                reasons.append(f"Eyes drowsy EAR={ear_val:.2f}")

        # PERCLOS penalty
        perclos_pen = min(perclos.perclos / 0.40, 1.0) * 18.0
        score -= perclos_pen
        if perclos.perclos > 0.15:
            reasons.append(f"PERCLOS {perclos.perclos:.1%}")

        # Temporal state flat penalty
        score -= _STATE_PENALTY.get(temporal.current, 0)

        if temporal.current == AttentionState.NO_FACE:
            reasons.append("No face detected")
        elif temporal.current == AttentionState.MULTIPLE_FACES:
            reasons.append(f"{face_count} faces in frame")
        elif temporal.current == AttentionState.SLEEPING:
            reasons.append(f"Sleeping ({perclos.long_closure_sec:.1f}s closure)")
        elif temporal.current == AttentionState.LOW_CONFIDENCE:
            reasons.append("Low detection confidence")
        elif temporal.current == AttentionState.OCCLUDED:
            reasons.append("Face partially occluded")

        score = max(0.0, min(100.0, score))

        # ── EMA smoothing — reset on state change for crisp transitions ───────
        state_changed = temporal.current != self._prev_state
        self._prev_state = temporal.current

        if state_changed and temporal.current == AttentionState.FOCUSED:
            # Snap to current score immediately when recovering to focused
            self._ema_attention = score
        else:
            self._ema_attention = self._ema(self._ema_attention, score)

        self._ema_drowsiness = self._ema(self._ema_drowsiness, perclos.drowsiness_score)

        return FusionResult(
            attention_score=round(self._ema_attention, 1),
            focus_state=_FOCUS_STATE_MAP.get(temporal.current, "warning"),
            drowsiness_score=round(self._ema_drowsiness, 1),
            confidence=confidence,
            reasons=reasons,
        )

    def _ema(self, prev: Optional[float], raw: float) -> float:
        if prev is None:
            return raw
        return self._alpha * raw + (1.0 - self._alpha) * prev
