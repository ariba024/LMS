"""
perclos.py — PERCLOS + blink rate tracker.

PERCLOS = Percentage of Eye Closure over a rolling time window.
  Standard NHTSA/FMCSA drowsiness metric.
  PERCLOS > 0.15 → drowsy warning
  PERCLOS > 0.40 → sleeping

Blink duration cap raised to 800 ms (was 500 ms) to correctly count
slow blinks that are a hallmark of drowsiness (600-800 ms range).
"""

import time
from collections import deque
from dataclasses import dataclass
from typing import Optional, Deque


@dataclass
class PerclosResult:
    perclos:           float   # 0.0–1.0
    blink_rate:        float   # blinks / minute (60-sec rolling)
    avg_blink_ms:      float   # ms
    long_closure_sec:  float   # current sustained closure in seconds
    drowsiness_score:  float   # 0–100 composite
    is_drowsy:         bool
    is_sleeping:       bool


class PerclosTracker:

    def __init__(
        self,
        window_sec:       float = 30.0,
        fps_estimate:     float = 15.0,
        perclos_drowsy:   float = 0.15,
        perclos_sleep:    float = 0.40,
        blink_window_sec: float = 60.0,
        blink_rate_min:   float = 8.0,
        blink_max_ms:     float = 800.0,   # raised from 500 ms
    ):
        self._perclos_drowsy = perclos_drowsy
        self._perclos_sleep  = perclos_sleep
        self._blink_rate_min = blink_rate_min
        self._blink_window   = blink_window_sec
        self._blink_max_ms   = blink_max_ms

        buf = int(window_sec * fps_estimate)
        self._closure_buf: Deque[bool] = deque(maxlen=buf)

        self._blink_times:     Deque[float] = deque()
        self._blink_durations: Deque[float] = deque(maxlen=60)

        self._eye_was_closed = False
        self._closure_start: Optional[float] = None
        self._long_start:    Optional[float] = None

    def update(
        self,
        eyes_closed: bool,
        in_blink:    bool,
        now:         Optional[float] = None,
    ) -> PerclosResult:
        now = now or time.monotonic()

        # ── PERCLOS buffer ──────────────────────────────────────────────────
        self._closure_buf.append(eyes_closed)
        n       = len(self._closure_buf)
        perclos = sum(self._closure_buf) / n if n else 0.0

        # ── Blink event detection (rising / falling edge) ───────────────────
        if eyes_closed and not self._eye_was_closed:
            self._closure_start = now
        if not eyes_closed and self._eye_was_closed:
            if self._closure_start is not None:
                dur_ms = (now - self._closure_start) * 1000.0
                # Count as blink if within 50–800 ms (raised cap for drowsy slow blinks)
                if 50 <= dur_ms <= self._blink_max_ms:
                    self._blink_times.append(now)
                    self._blink_durations.append(dur_ms)
            self._closure_start = None
        self._eye_was_closed = eyes_closed

        # Prune stale blink events
        cutoff = now - self._blink_window
        while self._blink_times and self._blink_times[0] < cutoff:
            self._blink_times.popleft()

        blink_rate = len(self._blink_times)
        avg_blink  = (
            sum(self._blink_durations) / len(self._blink_durations)
            if self._blink_durations else 0.0
        )

        # ── Sustained closure timer ──────────────────────────────────────────
        if eyes_closed:
            if self._long_start is None:
                self._long_start = now
            long_sec = now - self._long_start
        else:
            self._long_start = None
            long_sec = 0.0

        # ── Drowsiness score (0–100) ─────────────────────────────────────────
        perclos_pts = min(perclos / self._perclos_sleep, 1.0) * 55.0
        dur_pts     = min(avg_blink / 500.0, 1.0) * 25.0

        # Blink rate: penalise BOTH very low and very high rates
        # Normal range: 8-20 blinks/min.  Below 8 → drowsy. Above 20 → stress/alert.
        # Simple V-shaped penalty centred on 12 blinks/min:
        if blink_rate == 0 and n < 30:
            rate_pts = 0.0   # not enough data yet
        elif blink_rate < self._blink_rate_min:
            rate_pts = (self._blink_rate_min - blink_rate) / self._blink_rate_min * 20.0
        else:
            rate_pts = 0.0

        drow_score = min(perclos_pts + dur_pts + rate_pts, 100.0)

        return PerclosResult(
            perclos=round(perclos, 4),
            blink_rate=round(blink_rate, 1),
            avg_blink_ms=round(avg_blink, 1),
            long_closure_sec=round(long_sec, 2),
            drowsiness_score=round(drow_score, 1),
            is_drowsy=perclos >= self._perclos_drowsy,
            is_sleeping=perclos >= self._perclos_sleep or long_sec >= 2.5,
        )
