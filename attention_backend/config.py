"""
config.py — All tunable constants in one place.
Edit here instead of hunting through multiple files.
"""

# ── Head pose thresholds (degrees) ────────────────────────────────────────────
HEAD_YAW_WARNING_DEG    = 30    # start warning
HEAD_YAW_AWAY_DEG       = 45    # clearly looking away
HEAD_PITCH_WARNING_DEG  = 25
HEAD_PITCH_AWAY_DEG     = 40    # generous: laptop cameras sit above screen, natural reading adds pitch

# ── Head pose smoothing / calibration ─────────────────────────────────────────
HEAD_POSE_EMA_ALPHA      = 0.50  # 0=frozen, 1=raw — higher = more reactive
HEAD_POSE_MIN_CONFIDENCE = 0.30  # reject pose below this for looking_away decision

# ── EAR (Eye Aspect Ratio) ─────────────────────────────────────────────────────
EAR_CLOSED              = 0.20  # fallback if calibration hasn't run yet
EAR_OPEN                = 0.25  # fallback open threshold
BLINK_MAX_FRAMES        = 8     # closure > this frames = sustained, not a blink
EAR_SMOOTH_FRAMES       = 3     # rolling average window for noise reduction
EAR_CALIBRATION_FRAMES  = 60    # ~4 s at 15 fps — collect open-eye baseline
EAR_CLOSED_RATIO        = 0.75  # closed_threshold = baseline_ear * this
EAR_OPEN_RATIO          = 0.85  # open_threshold   = baseline_ear * this

# ── Iris gaze ──────────────────────────────────────────────────────────────────
IRIS_SIDEWAYS_OFFSET    = 0.38  # abs(iris_x - eye_center) / eye_width — raised to reduce false positives
IRIS_DOWN_RATIO         = 0.88  # iris_y / eye_height — nearly disabled; screen reading naturally pushes iris down

# ── PERCLOS ───────────────────────────────────────────────────────────────────
PERCLOS_WINDOW_SEC      = 30.0  # rolling window
PERCLOS_FPS_ESTIMATE    = 15.0  # used to size the buffer
PERCLOS_DROWSY          = 0.15  # 15 % → drowsy warning
PERCLOS_SLEEP           = 0.40  # 40 % → sleeping

# ── Blink stats ───────────────────────────────────────────────────────────────
BLINK_RATE_NORMAL_MIN   = 8     # blinks/min; below this → drowsy signal
BLINK_RATE_WINDOW_SEC   = 60    # rolling window for blink rate
BLINK_MAX_MS            = 800   # max blink duration (was 500 — extended for drowsy slow blinks)

# ── Temporal state machine (seconds) ─────────────────────────────────────────
LOOK_AWAY_WARNING_SEC    = 2.0   # looking away → WARNING
LOOK_AWAY_DISTRACTED_SEC = 5.0   # looking away → DISTRACTED
LOOK_BACK_RECOVER_SEC    = 3.0   # must look at screen this long to reset (hysteresis)
NO_FACE_GRACE_SEC        = 1.5   # no face → NO_FACE state
NO_FACE_RECOVER_SEC      = 0.5   # face back → resume normal
DROWSY_CONFIRM_SEC       = 8.0   # PERCLOS must be elevated this long → DROWSY
SLEEP_CLOSURE_SEC        = 2.5   # eyes closed continuously → SLEEPING
SLEEP_RECOVER_SEC        = 1.5   # eyes open this long to leave SLEEPING

# ── Confidence thresholds ─────────────────────────────────────────────────────
MIN_FACE_CONFIDENCE      = 0.40
MIN_LANDMARK_VISIBILITY  = 0.50
MAX_PNP_REPROJECTION_ERR = 30.0  # px; above → low-confidence head pose

# ── Calibration ───────────────────────────────────────────────────────────────
CALIBRATION_FRAMES      = 60    # frames before live detection (EAR + head pose baseline)

# ── Scoring weights ───────────────────────────────────────────────────────────
W_HEAD_POSE  = 0.40
W_EAR        = 0.30
W_TEMPORAL   = 0.30

# ── EMA smoothing ─────────────────────────────────────────────────────────────
SCORE_SMOOTHING_FRAMES   = 8    # alpha = 2/(N+1) ≈ 0.22
