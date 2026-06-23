"""
temporal.py — Hysteresis-based attention state machine.

Why temporal smoothing?
  Frame-by-frame classification produces jittery, unreliable states.
  Real systems (PERCLOS studies, NHTSA guidelines) define attention
  states over multi-second windows. A single glance to the side is NOT
  distraction; sustained gaze-away IS.

State priority (higher = overrides lower):
  sleeping > no_face > multiple_faces > low_confidence > occluded
  > distracted > drowsy > warning > focused

Hysteresis rule:
  Once in WARNING/DISTRACTED, the learner must look at the screen for
  LOOK_BACK_RECOVER_SEC (default 3 s) continuously before resetting
  to FOCUSED. This prevents oscillation at the boundary.

Transitions:
  focused       → warning     : look_away ≥ LOOK_AWAY_WARNING_SEC
  warning       → distracted  : look_away ≥ LOOK_AWAY_DISTRACTED_SEC
  warning/dist. → focused     : look_back ≥ LOOK_BACK_RECOVER_SEC (hysteresis)
  any           → no_face     : no face for ≥ NO_FACE_GRACE_SEC
  no_face       → focused     : face back for ≥ NO_FACE_RECOVER_SEC
  any           → drowsy      : is_drowsy AND elapsed ≥ DROWSY_CONFIRM_SEC
  any           → sleeping    : long_closure ≥ SLEEP_CLOSURE_SEC
  sleeping      → focused     : eyes_open for ≥ SLEEP_RECOVER_SEC
"""

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, Optional


class AttentionState(str, Enum):
    FOCUSED         = "focused"
    WARNING         = "warning"
    DISTRACTED      = "distracted"
    DROWSY          = "drowsy"
    SLEEPING        = "sleeping"
    NO_FACE         = "no_face"
    MULTIPLE_FACES  = "multiple_faces"
    OCCLUDED        = "occluded"
    LOW_CONFIDENCE  = "low_confidence"


@dataclass
class TemporalState:
    current:      AttentionState
    duration_sec: float           # seconds in current state
    previous:     AttentionState


class TemporalStateMachine:

    def __init__(
        self,
        look_away_warning_sec:    float = 2.0,
        look_away_distracted_sec: float = 5.0,
        look_back_recover_sec:    float = 3.0,
        no_face_grace_sec:        float = 1.5,
        no_face_recover_sec:      float = 0.5,
        drowsy_confirm_sec:       float = 8.0,
        sleep_closure_sec:        float = 2.5,
        sleep_recover_sec:        float = 1.5,
    ):
        self._cfg = dict(
            look_away_warning=look_away_warning_sec,
            look_away_distracted=look_away_distracted_sec,
            look_back_recover=look_back_recover_sec,
            no_face_grace=no_face_grace_sec,
            no_face_recover=no_face_recover_sec,
            drowsy_confirm=drowsy_confirm_sec,
            sleep_closure=sleep_closure_sec,
            sleep_recover=sleep_recover_sec,
        )

        self._state      = AttentionState.FOCUSED
        self._prev_state = AttentionState.FOCUSED
        self._entered_at = time.monotonic()

        # Timers: record when each condition FIRST became true (None = not active)
        self._timers: Dict[str, Optional[float]] = {k: None for k in [
            "looking_away", "looking_back",
            "no_face", "face_back",
            "drowsy", "eyes_open",
        ]}

    # ── Public ─────────────────────────────────────────────────────────────────

    def update(
        self,
        looking_away:     bool,
        eyes_closed:      bool,
        is_drowsy:        bool,
        is_sleeping:      bool,
        face_count:       int,
        low_confidence:   bool,
        occluded:         bool,
        long_closure_sec: float = 0.0,
    ) -> TemporalState:
        now = time.monotonic()

        # Update condition timers
        self._tick("looking_away", looking_away, now)
        self._tick("looking_back", not looking_away, now)
        self._tick("no_face",      face_count == 0, now)
        self._tick("face_back",    face_count > 0,  now)
        self._tick("drowsy",       is_drowsy, now)
        self._tick("eyes_open",    not eyes_closed, now)

        new = self._resolve(
            looking_away, eyes_closed, is_drowsy, is_sleeping,
            face_count, low_confidence, occluded, long_closure_sec, now,
        )

        if new != self._state:
            self._prev_state = self._state
            self._state      = new
            self._entered_at = now

        return TemporalState(
            current=self._state,
            duration_sec=round(now - self._entered_at, 2),
            previous=self._prev_state,
        )

    # ── Internal ────────────────────────────────────────────────────────────────

    def _tick(self, key: str, condition: bool, now: float) -> None:
        if condition:
            if self._timers[key] is None:
                self._timers[key] = now
        else:
            self._timers[key] = None

    def _elapsed(self, key: str, now: float) -> float:
        t = self._timers[key]
        return (now - t) if t is not None else 0.0

    def _resolve(
        self,
        looking_away, eyes_closed, is_drowsy, is_sleeping,
        face_count, low_confidence, occluded, long_closure_sec, now,
    ) -> AttentionState:
        cfg = self._cfg
        el  = lambda k: self._elapsed(k, now)   # noqa: E731

        # Priority order: highest severity first
        if long_closure_sec >= cfg["sleep_closure"]:
            return AttentionState.SLEEPING

        if self._state == AttentionState.SLEEPING:
            if el("eyes_open") >= cfg["sleep_recover"]:
                return AttentionState.FOCUSED
            return AttentionState.SLEEPING   # stay until recovered

        if face_count == 0:
            if el("no_face") >= cfg["no_face_grace"]:
                return AttentionState.NO_FACE
            return self._state  # grace period — hold current

        if face_count > 1:
            return AttentionState.MULTIPLE_FACES

        if low_confidence:
            return AttentionState.LOW_CONFIDENCE

        if occluded:
            return AttentionState.OCCLUDED

        # Face back after no_face
        if self._state == AttentionState.NO_FACE:
            if el("face_back") >= cfg["no_face_recover"]:
                return AttentionState.FOCUSED
            return AttentionState.NO_FACE

        # Drowsiness (confirmed over window)
        if is_drowsy and el("drowsy") >= cfg["drowsy_confirm"]:
            return AttentionState.DROWSY
        if self._state == AttentionState.DROWSY and not is_drowsy:
            return AttentionState.FOCUSED

        # Gaze-away state machine
        if looking_away:
            t = el("looking_away")
            if t >= cfg["look_away_distracted"]:
                return AttentionState.DISTRACTED
            if t >= cfg["look_away_warning"]:
                return AttentionState.WARNING
            return self._state  # not yet at threshold — hold current

        # Recovering from WARNING / DISTRACTED (hysteresis)
        if self._state in (AttentionState.WARNING, AttentionState.DISTRACTED):
            if el("looking_back") >= cfg["look_back_recover"]:
                return AttentionState.FOCUSED
            return self._state  # hold until hysteresis satisfied

        return AttentionState.FOCUSED
