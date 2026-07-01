"""
api/routers/progress.py -- Learner progress and adaptive learning route endpoints.

GET  /api/v1/progress/me/enrolled-courses               Courses the authenticated learner has started
GET  /api/v1/progress/{learner_id}/course/{course_id}   Full progress for a learner on a course
GET  /api/v1/progress/{learner_id}/recommendations      Adaptive learning recommendations
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from api.db import get_db
from api.dependencies import get_current_user, get_progress_tracker
from api.models.progress import WeakTopicRow
from api.models.users import UserRow
from api.routers.gamification import award_lesson_xp
from api.schemas import (
    LearnerProgressResponse,
    LessonRecordItem,
    WeakTopicItem,
    RecommendationItem,
)


class _LessonStartRequest(BaseModel):
    module_idx: int
    lesson_idx: int


class _LessonCompleteRequest(BaseModel):
    module_idx: int
    lesson_idx: int
    score: float | None = None  # 0.0–1.0; None = watched without a KC


class _QuizAttemptRequest(BaseModel):
    module_idx:     int
    lesson_idx:     int
    question_id:    str
    question_text:  str = ""
    learner_answer: str = ""
    correct_answer: str = ""
    is_correct:     bool
    topic_tag:      str = ""
    quiz_type:      str = "lesson_checkpoint"

router = APIRouter(prefix="/api/v1/progress", tags=["Learner Progress"])


@router.get("/me/enrolled-courses")
def get_enrolled_courses(current_user: UserRow = Depends(get_current_user)):
    """Return course IDs where the authenticated learner has at least one lesson record."""
    from api.db import SessionLocal
    from api.models.progress import LessonRecordRow

    with SessionLocal() as db:
        rows = (
            db.query(LessonRecordRow.course_id)
            .filter(LessonRecordRow.learner_id == current_user.email)
            .distinct()
            .all()
        )
    return {"course_ids": [r.course_id for r in rows]}


@router.get("/me/summary")
def get_progress_summary(current_user: UserRow = Depends(get_current_user)):
    """
    Per-course progress summary for the authenticated learner.

    Returns a mapping of course_id → {completed_lessons, total_lessons, percent}.
    Used by the Flutter app to populate course.progress on the learner dashboard.
    """
    import json as _json
    from sqlalchemy import func
    from api.db import SessionLocal
    from api.models.progress import LessonRecordRow
    from api.models.courses import CourseScriptRow

    with SessionLocal() as db:
        course_rows = (
            db.query(LessonRecordRow.course_id)
            .filter(LessonRecordRow.learner_id == current_user.email)
            .distinct()
            .all()
        )
        course_ids = [r.course_id for r in course_rows]

        result: dict = {}
        for course_id in course_ids:
            completed = (
                db.query(func.count(LessonRecordRow.lesson_idx))
                .filter(
                    LessonRecordRow.learner_id == current_user.email,
                    LessonRecordRow.course_id == course_id,
                    LessonRecordRow.completed_at.isnot(None),
                )
                .scalar() or 0
            )
            script_row = db.query(CourseScriptRow).filter(
                CourseScriptRow.script_id == course_id
            ).first()
            if script_row:
                total = script_row.total_lessons
                if not total:
                    try:
                        script = _json.loads(script_row.course_script_json)
                        total = sum(
                            len(m.get("lessons", [])) for m in script.get("modules", [])
                        )
                    except Exception:
                        total = 0
            else:
                total = 0
            percent = round(completed * 100 / total) if total > 0 else 0
            result[course_id] = {
                "completed_lessons": completed,
                "total_lessons": total,
                "percent": percent,
            }
    return result


@router.post("/{learner_id}/course/{course_id}/lesson-start", status_code=204)
def record_lesson_start(
    learner_id: str,
    course_id: str,
    body: _LessonStartRequest,
    progress_tracker=Depends(get_progress_tracker),
    current_user: UserRow = Depends(get_current_user),
):
    """Record that a learner opened a lesson (creates the lesson_records row)."""
    if not progress_tracker:
        raise HTTPException(status_code=503, detail="Progress tracker not initialised.")
    effective_id = learner_id if current_user.role == "admin" else current_user.email
    progress_tracker.record_lesson_start(effective_id, course_id, body.module_idx, body.lesson_idx)


@router.post("/{learner_id}/course/{course_id}/lesson-complete", status_code=204)
def record_lesson_complete(
    learner_id: str,
    course_id: str,
    body: _LessonCompleteRequest,
    progress_tracker=Depends(get_progress_tracker),
    current_user: UserRow = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Mark a lesson as completed.  If `score` is present the lesson had a
    knowledge-check; the score (0.0–1.0) is stored as the checkpoint score
    and used to drive recommendations.  If `score` is absent the lesson was
    watched to the end without a quiz.
    """
    if not progress_tracker:
        raise HTTPException(status_code=503, detail="Progress tracker not initialised.")
    effective_id = learner_id if current_user.role == "admin" else current_user.email
    if body.score is not None:
        progress_tracker.record_lesson_checkpoint(
            effective_id, course_id, body.module_idx, body.lesson_idx, body.score
        )
        # Award XP proportional to KC score (50 base + up to 50 bonus)
        xp = 50 + round(body.score * 50)
    else:
        progress_tracker.record_lesson_complete(
            effective_id, course_id, body.module_idx, body.lesson_idx
        )
        xp = 50  # flat XP for watching a lesson without a quiz

    try:
        award_lesson_xp(effective_id, course_id, xp, db)
    except Exception:
        pass  # XP is non-critical; don't fail the progress record


@router.post("/{learner_id}/course/{course_id}/quiz-attempt", status_code=204)
def record_quiz_attempt(
    learner_id: str,
    course_id: str,
    body: _QuizAttemptRequest,
    progress_tracker=Depends(get_progress_tracker),
    current_user: UserRow = Depends(get_current_user),
):
    """
    Record a single KC answer.  Automatically updates the weak-topics table so
    that get_recommendations() can flag topics the learner struggles with.
    """
    if not progress_tracker:
        raise HTTPException(status_code=503, detail="Progress tracker not initialised.")
    effective_id = learner_id if current_user.role == "admin" else current_user.email
    progress_tracker.record_quiz_attempt(
        learner_id=effective_id,
        course_id=course_id,
        module_idx=body.module_idx,
        lesson_idx=body.lesson_idx,
        question_id=body.question_id,
        question_text=body.question_text,
        learner_answer=body.learner_answer,
        correct_answer=body.correct_answer,
        is_correct=body.is_correct,
        topic_tag=body.topic_tag or f"m{body.module_idx}l{body.lesson_idx}",
        quiz_type=body.quiz_type,
    )


@router.get("/{learner_id}/course/{course_id}", response_model=LearnerProgressResponse)
def get_course_progress(
    learner_id:       str,
    course_id:        str,
    progress_tracker = Depends(get_progress_tracker),
    current_user: UserRow = Depends(get_current_user),
):
    """
    Full progress summary for a learner on a given course.

    `course_id` is the document's filename as stored in the vector DB
    (same value as `source_file` in the tutor session).
    Includes lesson completion status, quiz scores, weak topics, and recommendations.
    """
    if not progress_tracker:
        raise HTTPException(status_code=503, detail="Progress tracker is not initialised.")

    effective_id = learner_id if current_user.role == "admin" else current_user.email
    prog = progress_tracker.get_course_progress(effective_id, course_id)
    recs = progress_tracker.get_recommendations(effective_id, course_id)

    return LearnerProgressResponse(
        learner_id=effective_id,
        course_id=course_id,
        completed_lessons=prog.completed_lesson_count,
        average_checkpoint_score=prog.average_checkpoint_score,
        lesson_records=[
            LessonRecordItem(
                module_idx=r.module_idx,
                lesson_idx=r.lesson_idx,
                started_at=r.started_at,
                completed_at=r.completed_at,
                checkpoint_score=r.checkpoint_score,
                module_checkpoint_score=r.module_checkpoint_score,
            )
            for r in prog.lesson_records
        ],
        weak_topics=[
            WeakTopicItem(
                topic=t.topic,
                accuracy=round(t.accuracy, 2),
                total_attempts=t.total_count,
            )
            for t in prog.weak_topics
        ],
        recommendations=[RecommendationItem(**r) for r in recs],
    )


@router.get("/{learner_id}/recommendations", response_model=list[RecommendationItem])
def get_recommendations(
    learner_id:       str,
    course_id:        str = Query(..., description="Course (source_file) to get recommendations for"),
    progress_tracker = Depends(get_progress_tracker),
    current_user: UserRow = Depends(get_current_user),
):
    """
    Adaptive learning recommendations for a learner.

    Returns a prioritised list of:
    - Lessons to re-study (scored below 60%)
    - Weak topics to focus on (accuracy below 60% across at least 2 questions)
    """
    if not progress_tracker:
        raise HTTPException(status_code=503, detail="Progress tracker is not initialised.")

    effective_id = learner_id if current_user.role == "admin" else current_user.email
    recs = progress_tracker.get_recommendations(effective_id, course_id)
    return [RecommendationItem(**r) for r in recs]


class _WeakTopicAdminItem(BaseModel):
    course_id: str
    topic: str
    accuracy: float
    total_attempts: int


@router.get("/{learner_id}/weak-topics", response_model=list[_WeakTopicAdminItem])
def get_learner_weak_topics(
    learner_id: str,
    db: Session = Depends(get_db),
    current_user: UserRow = Depends(get_current_user),
):
    """All weak topics for a learner across all courses. Admin or self only."""
    if current_user.role != "admin" and current_user.email != learner_id:
        raise HTTPException(status_code=403, detail="Access denied.")
    rows = (
        db.query(WeakTopicRow)
        .filter(
            WeakTopicRow.learner_id == learner_id,
            WeakTopicRow.total_count > 0,
        )
        .all()
    )
    return [
        _WeakTopicAdminItem(
            course_id=r.course_id,
            topic=r.topic,
            accuracy=round(
                (r.total_count - r.miss_count) / r.total_count, 2
            ),
            total_attempts=r.total_count,
        )
        for r in rows
    ]
