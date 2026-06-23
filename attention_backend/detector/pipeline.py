"""
pipeline.py — Main attention detection orchestrator.

7 stages per frame:
  1  FaceMeshDetector  → landmarks, face count
  2  HeadPoseEstimator → yaw, pitch, roll (EMA-smoothed, calibrated)
  3  IrisGazeDetector  → iris-based gaze (secondary signal)
  4  EARDetector       → ear_left, ear_right (smoothed, calibrated)
  5  PerclosTracker    → perclos, blink_rate, drowsiness_score
  6  TemporalStateMachine → 9-state with hysteresis
  7  ConfidenceFusion  → attention_score, focus_state, confidence

Not thread-safe — run from a single-worker ThreadPoolExecutor.
"""

import logging
from dataclasses import dataclass, asdict
from typing import Optional, List

import config
from detector.face_mesh import FaceMeshDetector, FaceData
from detector.head_pose import HeadPoseEstimator, HeadPose
from detector.gaze import IrisGazeDetector, GazeResult
from detector.ear import EARDetector, EARResult
from detector.perclos import PerclosTracker, PerclosResult
from detector.temporal import TemporalStateMachine, AttentionState, TemporalState
from detector.fusion import ConfidenceFusion, FusionResult

log = logging.getLogger(__name__)


@dataclass
class AttentionResult:
    # ── Composite scores ──────────────────────────────────────────────────────
    attention_score:  float
    focus_state:      str
    attention_state:  str
    drowsiness_score: float
    confidence:       float
    reasons:          List[str]

    # ── Head pose ─────────────────────────────────────────────────────────────
    yaw:            float
    pitch:          float
    roll:           float
    gaze_direction: str

    # ── Eye / drowsiness signals ───────────────────────────────────────────────
    ear_left:         float
    ear_right:        float
    ear_avg:          float
    perclos:          float
    blink_rate:       float
    avg_blink_ms:     float
    long_closure_sec: float

    # ── Frame metadata ─────────────────────────────────────────────────────────
    face_count: int
    frame_id:   int
    calibrated: bool   # True once EAR + head pose baselines are ready

    def to_dict(self) -> dict:
        return asdict(self)


class AttentionPipeline:
    """Create once, call analyze(jpeg_bytes) per frame. Not thread-safe."""

    def __init__(self) -> None:
        log.info("Initialising attention pipeline v2 (with iris gaze + calibration)…")
        self._mesh     = FaceMeshDetector(max_faces=3)
        self._pose     = HeadPoseEstimator(ema_alpha=config.HEAD_POSE_EMA_ALPHA)
        self._iris     = IrisGazeDetector(
            sideways_offset=config.IRIS_SIDEWAYS_OFFSET,
            down_ratio=config.IRIS_DOWN_RATIO,
        )
        self._ear      = EARDetector(
            closed_threshold=config.EAR_CLOSED,
            open_threshold=config.EAR_OPEN,
            blink_max_frames=config.BLINK_MAX_FRAMES,
            smooth_frames=config.EAR_SMOOTH_FRAMES,
        )
        self._perclos  = PerclosTracker(
            window_sec=config.PERCLOS_WINDOW_SEC,
            fps_estimate=config.PERCLOS_FPS_ESTIMATE,
            perclos_drowsy=config.PERCLOS_DROWSY,
            perclos_sleep=config.PERCLOS_SLEEP,
            blink_max_ms=config.BLINK_MAX_MS,
        )
        self._temporal = TemporalStateMachine(
            look_away_warning_sec=config.LOOK_AWAY_WARNING_SEC,
            look_away_distracted_sec=config.LOOK_AWAY_DISTRACTED_SEC,
            look_back_recover_sec=config.LOOK_BACK_RECOVER_SEC,
            no_face_grace_sec=config.NO_FACE_GRACE_SEC,
            no_face_recover_sec=config.NO_FACE_RECOVER_SEC,
            drowsy_confirm_sec=config.DROWSY_CONFIRM_SEC,
            sleep_closure_sec=config.SLEEP_CLOSURE_SEC,
            sleep_recover_sec=config.SLEEP_RECOVER_SEC,
        )
        self._fusion   = ConfidenceFusion(smoothing_frames=config.SCORE_SMOOTHING_FRAMES)
        self._frame_id = 0
        log.info("Pipeline ready.")

    # ── Public API ─────────────────────────────────────────────────────────────

    def analyze(self, jpeg_bytes: bytes) -> AttentionResult:
        self._frame_id += 1
        fid = self._frame_id

        # ── Stage 1: Face mesh ─────────────────────────────────────────────────
        mesh = self._mesh.detect(jpeg_bytes)
        if mesh is None:
            log.debug("Frame %d: decode failed", fid)
            return self._null_result(fid)

        face_count = mesh.face_count
        face: Optional[FaceData] = mesh.primary_face

        # ── Stage 2: Head pose ─────────────────────────────────────────────────
        head_pose: Optional[HeadPose] = None
        if face is not None and mesh.frame_w > 0:
            try:
                head_pose = self._pose.estimate(face, mesh.frame_w, mesh.frame_h)
            except Exception as exc:
                log.debug("Frame %d: head pose error: %s", fid, exc)

        # ── Stage 3: Iris gaze ─────────────────────────────────────────────────
        iris_gaze: Optional[GazeResult] = None
        if face is not None:
            try:
                iris_gaze = self._iris.compute(face)
            except Exception as exc:
                log.debug("Frame %d: iris gaze error: %s", fid, exc)

        # ── Stage 4: EAR ──────────────────────────────────────────────────────
        ear_result: Optional[EARResult] = None
        if face is not None:
            try:
                ear_result = self._ear.compute(face)
            except Exception as exc:
                log.debug("Frame %d: EAR error: %s", fid, exc)

        # ── Stage 5: PERCLOS ───────────────────────────────────────────────────
        eyes_closed = ear_result.eyes_closed if ear_result else False
        in_blink    = ear_result.in_blink    if ear_result else False
        perclos     = self._perclos.update(eyes_closed, in_blink)

        # ── Derived flags ──────────────────────────────────────────────────────
        looking_away   = False
        low_confidence = False
        occluded       = False

        if head_pose is not None:
            if head_pose.confidence >= config.HEAD_POSE_MIN_CONFIDENCE:
                head_yaw_away   = abs(head_pose.yaw)   >= config.HEAD_YAW_AWAY_DEG
                head_pitch_away = abs(head_pose.pitch) >= config.HEAD_PITCH_AWAY_DEG

                # Primary signal: head yaw (left/right) — reliable
                # Iris can CONFIRM yaw only (not pitch — screen reading pushes iris down legitimately)
                if head_yaw_away:
                    looking_away = True
                elif head_pitch_away:
                    looking_away = True
                elif iris_gaze is not None and iris_gaze.looking_sideways:
                    # Iris says sideways AND head is already in warning zone → confirm
                    in_yaw_warning = abs(head_pose.yaw) >= config.HEAD_YAW_WARNING_DEG
                    if in_yaw_warning:
                        looking_away = True
                # iris alone (no head deviation) → NOT flagged; too many false positives
            else:
                low_confidence = True
        elif face is not None:
            # Face detected but pose failed — only flag if iris is very strongly sideways
            low_confidence = True
            if iris_gaze is not None and iris_gaze.looking_sideways:
                looking_away = True

        # When no face: explicitly do NOT inherit looking_away from prior frame
        if face is None:
            looking_away = False

        if face is not None:
            occluded = face.detection_confidence < config.MIN_LANDMARK_VISIBILITY

        # ── Debug log every 15 frames ─────────────────────────────────────────
        if fid % 15 == 0:
            hp_str = (f"yaw={head_pose.yaw:+.1f} pitch={head_pose.pitch:+.1f} "
                      f"conf={head_pose.confidence:.2f}" if head_pose else "no-pose")
            ig_str = (f"h_off={iris_gaze.avg_h_offset:.2f} v={iris_gaze.avg_v_ratio:.2f} "
                      f"sw={iris_gaze.looking_sideways}" if iris_gaze else "no-iris")
            ear_str = (f"avg={ear_result.avg_ear:.3f} sm={ear_result.smoothed_ear:.3f} "
                       f"closed={ear_result.eyes_closed}" if ear_result else "no-ear")
            log.info("f#%d faces=%d %s | iris:%s | ear:%s | away=%s",
                     fid, face_count, hp_str, ig_str, ear_str, looking_away)

        # ── Stage 6: Temporal state machine ───────────────────────────────────
        temporal = self._temporal.update(
            looking_away=looking_away,
            eyes_closed=eyes_closed,
            is_drowsy=perclos.is_drowsy,
            is_sleeping=perclos.is_sleeping,
            face_count=face_count,
            low_confidence=low_confidence,
            occluded=occluded,
            long_closure_sec=perclos.long_closure_sec,
        )

        # ── Stage 7: Confidence fusion ─────────────────────────────────────────
        fusion = self._fusion.fuse(temporal, head_pose, ear_result, perclos, face_count)

        calibrated = self._ear.is_calibrated and self._pose.is_calibrated

        return AttentionResult(
            attention_score=fusion.attention_score,
            focus_state=fusion.focus_state,
            attention_state=temporal.current.value,
            drowsiness_score=fusion.drowsiness_score,
            confidence=fusion.confidence,
            reasons=fusion.reasons,
            yaw=head_pose.yaw      if head_pose else 0.0,
            pitch=head_pose.pitch  if head_pose else 0.0,
            roll=head_pose.roll    if head_pose else 0.0,
            gaze_direction=head_pose.gaze_direction if head_pose else "unknown",
            ear_left=ear_result.left_ear    if ear_result else 0.0,
            ear_right=ear_result.right_ear  if ear_result else 0.0,
            ear_avg=ear_result.avg_ear      if ear_result else 0.0,
            perclos=perclos.perclos,
            blink_rate=perclos.blink_rate,
            avg_blink_ms=perclos.avg_blink_ms,
            long_closure_sec=perclos.long_closure_sec,
            face_count=face_count,
            frame_id=fid,
            calibrated=calibrated,
        )

    def close(self) -> None:
        self._mesh.close()

    # ── Internal ───────────────────────────────────────────────────────────────

    def _null_result(self, fid: int) -> AttentionResult:
        perclos  = self._perclos.update(False, False)
        temporal = self._temporal.update(
            looking_away=False, eyes_closed=False, is_drowsy=False,
            is_sleeping=False, face_count=0, low_confidence=False, occluded=False,
        )
        fusion = self._fusion.fuse(temporal, None, None, perclos, 0)
        return AttentionResult(
            attention_score=fusion.attention_score,
            focus_state=fusion.focus_state,
            attention_state=temporal.current.value,
            drowsiness_score=fusion.drowsiness_score,
            confidence=0.0,
            reasons=["Frame decode failed"],
            yaw=0.0, pitch=0.0, roll=0.0, gaze_direction="unknown",
            ear_left=0.0, ear_right=0.0, ear_avg=0.0,
            perclos=perclos.perclos,
            blink_rate=perclos.blink_rate,
            avg_blink_ms=perclos.avg_blink_ms,
            long_closure_sec=0.0,
            face_count=0, frame_id=fid, calibrated=False,
        )
