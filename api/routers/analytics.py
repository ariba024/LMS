"""
api/routers/analytics.py -- Platform-wide analytics overview.

GET /api/v1/analytics/overview
"""

from __future__ import annotations

import time
from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, distinct

from api.db import SessionLocal
from api.dependencies import require_admin
from api.models.courses import CourseScriptRow
from api.models.progress import AssessmentAttemptRow, LessonRecordRow
from api.models.renders import VideoRenderRow
from api.models.sessions import TutorSessionRow
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/analytics", tags=["Analytics"])

_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


class MonthlyActivity(BaseModel):
    month: str
    count: int


class OverviewResponse(BaseModel):
    total_courses:        int
    total_videos:         int
    total_learners:       int
    active_learners:      int
    total_ai_sessions:    int
    new_this_month:       int
    total_learning_hours: float
    learner_activity:     list[MonthlyActivity]
    generation_by_month:  list[MonthlyActivity]
    style_distribution:   dict[str, int]


@router.get("/overview", response_model=OverviewResponse)
def get_overview(_=Depends(require_admin)):
    """
    Platform-wide stats computed with SQL aggregations — no full table scans
    into Python memory.
    """
    thirty_ago = time.time() - 30 * 86400

    with SessionLocal() as db:
        total_courses = db.query(CourseScriptRow).count()

        total_videos = (
            db.query(VideoRenderRow)
            .filter(VideoRenderRow.status == "completed")
            .count()
        )

        total_learners = (
            db.query(func.count(distinct(LessonRecordRow.learner_id)))
            .scalar() or 0
        )

        active_learners = (
            db.query(func.count(distinct(LessonRecordRow.learner_id)))
            .filter(LessonRecordRow.started_at >= thirty_ago)
            .scalar() or 0
        )

        total_ai_sessions = (
            db.query(func.count(TutorSessionRow.session_id)).scalar() or 0
        )

        now = datetime.now(tz=timezone.utc)

        # New learners registered this calendar month
        this_month_ts = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0).timestamp()
        new_this_month = (
            db.query(func.count(UserRow.id))
            .filter(
                UserRow.created_at >= this_month_ts,
                UserRow.role == "learner",
            )
            .scalar() or 0
        )

        # Total learning hours: sum of lesson durations for completed lessons
        from sqlalchemy import text as _text
        _raw = db.execute(
            _text(
                "SELECT COALESCE(SUM(completed_at - started_at), 0)"
                " FROM lesson_records"
                " WHERE completed_at IS NOT NULL AND completed_at > started_at"
            )
        ).scalar() or 0.0
        total_learning_hours = round(float(_raw) / 3600, 1)

        # Monthly unique active learners for the past 6 months.
        # Month boundaries are computed in Python (avoids dialect-specific date
        # functions), then 6 small indexed time-window queries are fired.
        activity: list[MonthlyActivity] = []
        for i in range(5, -1, -1):
            # First day of the target month (going back i months)
            month_dt = (now.replace(day=1) - timedelta(days=30 * i)).replace(
                day=1, hour=0, minute=0, second=0, microsecond=0
            )
            # First day of the following month
            if month_dt.month == 12:
                next_dt = month_dt.replace(year=month_dt.year + 1, month=1)
            else:
                next_dt = month_dt.replace(month=month_dt.month + 1)

            cnt = (
                db.query(func.count(distinct(LessonRecordRow.learner_id)))
                .filter(
                    LessonRecordRow.started_at >= month_dt.timestamp(),
                    LessonRecordRow.started_at <  next_dt.timestamp(),
                )
                .scalar() or 0
            )
            activity.append(MonthlyActivity(
                month=_MONTHS[month_dt.month - 1],
                count=cnt,
            ))

        style_dist: dict[str, int] = dict(
            db.query(VideoRenderRow.style, func.count(VideoRenderRow.render_id))
            .filter(VideoRenderRow.status == "completed")
            .group_by(VideoRenderRow.style)
            .all()
        )

        # Monthly course generation counts for the same 6-month window.
        # Uses CourseScriptRow.generated_at (unix timestamp), already indexed.
        generation: list[MonthlyActivity] = []
        for i in range(5, -1, -1):
            month_dt = (now.replace(day=1) - timedelta(days=30 * i)).replace(
                day=1, hour=0, minute=0, second=0, microsecond=0
            )
            if month_dt.month == 12:
                next_dt = month_dt.replace(year=month_dt.year + 1, month=1)
            else:
                next_dt = month_dt.replace(month=month_dt.month + 1)

            cnt = (
                db.query(func.count(CourseScriptRow.script_id))
                .filter(
                    CourseScriptRow.generated_at >= month_dt.timestamp(),
                    CourseScriptRow.generated_at <  next_dt.timestamp(),
                )
                .scalar() or 0
            )
            generation.append(MonthlyActivity(
                month=_MONTHS[month_dt.month - 1],
                count=cnt,
            ))

    return OverviewResponse(
        total_courses=total_courses,
        total_videos=total_videos,
        total_learners=total_learners,
        active_learners=active_learners,
        total_ai_sessions=total_ai_sessions,
        new_this_month=new_this_month,
        total_learning_hours=total_learning_hours,
        learner_activity=activity,
        generation_by_month=generation,
        style_distribution=style_dist,
    )


# ── Pydantic response models ────────────────────────────────────────────────────

class CourseStatItem(BaseModel):
    course_id:          str
    title:              str
    enrolled_learners:  int
    completed_learners: int
    completion_rate:    float
    pass_rate:          float
    avg_score:          float
    total_attempts:     int


class CourseStatsResponse(BaseModel):
    courses: list[CourseStatItem]


class TutorStatsResponse(BaseModel):
    total_sessions:    int
    active_learners:   int
    sessions_by_month: list[MonthlyActivity]
    top_courses:       list[dict]


class FunnelStep(BaseModel):
    label: str
    count: int


class FunnelResponse(BaseModel):
    steps: list[FunnelStep]


# ── Course analytics ────────────────────────────────────────────────────────────

@router.get("/course-stats", response_model=CourseStatsResponse)
def get_course_stats(_=Depends(require_admin)):
    """
    Per-course metrics: enrolled learners, completion rate, assessment pass rate,
    average score, and total attempts.  Only includes courses that have at least
    one lesson record or assessment attempt.
    """
    from sqlalchemy import text

    with SessionLocal() as db:
        # Course titles from the scripts table (avoids JSON parsing)
        course_rows = db.query(
            CourseScriptRow.script_id, CourseScriptRow.course_title
        ).all()
        title_map = {r.script_id: r.course_title for r in course_rows}

        # Learners who started at least one lesson per course
        enrolled_rows = db.execute(text(
            "SELECT course_id, COUNT(DISTINCT learner_id)"
            " FROM lesson_records GROUP BY course_id"
        )).fetchall()
        enrolled: dict[str, int] = {r[0]: int(r[1]) for r in enrolled_rows}

        # Learners who completed at least one lesson per course
        completed_rows = db.execute(text(
            "SELECT course_id, COUNT(DISTINCT learner_id)"
            " FROM lesson_records WHERE completed_at IS NOT NULL GROUP BY course_id"
        )).fetchall()
        completed: dict[str, int] = {r[0]: int(r[1]) for r in completed_rows}

        # Assessment stats (total attempts, passed count, avg score) per course
        assess_rows = db.execute(text(
            "SELECT script_id, COUNT(*), COALESCE(SUM(passed),0), COALESCE(AVG(score),0)"
            " FROM assessment_attempts GROUP BY script_id"
        )).fetchall()
        assess: dict[str, tuple] = {
            r[0]: (int(r[1]), int(r[2]), float(r[3]))
            for r in assess_rows
        }

    # Union of courses that appear in either lesson_records or assessment_attempts
    # and are known to the course library
    course_ids = (set(enrolled.keys()) | set(assess.keys())) & set(title_map.keys())

    items: list[CourseStatItem] = []
    for cid in course_ids:
        e = enrolled.get(cid, 0)
        c = completed.get(cid, 0)
        total_att, pass_cnt, avg_sc = assess.get(cid, (0, 0, 0.0))
        items.append(CourseStatItem(
            course_id=cid,
            title=title_map[cid],
            enrolled_learners=e,
            completed_learners=c,
            completion_rate=round(c / e, 2) if e > 0 else 0.0,
            pass_rate=round(pass_cnt / total_att, 2) if total_att > 0 else 0.0,
            avg_score=round(avg_sc, 1),
            total_attempts=total_att,
        ))

    items.sort(key=lambda x: x.enrolled_learners, reverse=True)
    return CourseStatsResponse(courses=items)


# ── AI Tutor analytics ──────────────────────────────────────────────────────────

@router.get("/tutor-stats", response_model=TutorStatsResponse)
def get_tutor_stats(_=Depends(require_admin)):
    """
    AI Tutor session breakdown: monthly trend, active learners, and top courses
    by session count.
    """
    from sqlalchemy import text

    thirty_ago = time.time() - 30 * 86400
    now = datetime.now(tz=timezone.utc)

    with SessionLocal() as db:
        total_sessions = (
            db.query(func.count(TutorSessionRow.session_id)).scalar() or 0
        )

        active_learners = (
            db.query(func.count(distinct(TutorSessionRow.learner_id)))
            .filter(TutorSessionRow.updated_at >= thirty_ago)
            .scalar() or 0
        )

        # Monthly session counts for the past 6 months
        sessions_by_month: list[MonthlyActivity] = []
        for i in range(5, -1, -1):
            month_dt = (now.replace(day=1) - timedelta(days=30 * i)).replace(
                day=1, hour=0, minute=0, second=0, microsecond=0
            )
            if month_dt.month == 12:
                next_dt = month_dt.replace(year=month_dt.year + 1, month=1)
            else:
                next_dt = month_dt.replace(month=month_dt.month + 1)
            cnt = (
                db.query(func.count(TutorSessionRow.session_id))
                .filter(
                    TutorSessionRow.created_at >= month_dt.timestamp(),
                    TutorSessionRow.created_at <  next_dt.timestamp(),
                )
                .scalar() or 0
            )
            sessions_by_month.append(MonthlyActivity(
                month=_MONTHS[month_dt.month - 1],
                count=cnt,
            ))

        # Top 5 courses by session count
        top_rows = db.execute(text(
            "SELECT source_file, course_title, COUNT(*) as cnt"
            " FROM tutor_sessions"
            " GROUP BY source_file ORDER BY cnt DESC LIMIT 5"
        )).fetchall()
        top_courses = [
            {"course_id": r[0], "title": r[1] or r[0], "sessions": int(r[2])}
            for r in top_rows
        ]

    return TutorStatsResponse(
        total_sessions=total_sessions,
        active_learners=active_learners,
        sessions_by_month=sessions_by_month,
        top_courses=top_courses,
    )


# ── Engagement funnel ───────────────────────────────────────────────────────────

@router.get("/funnel", response_model=FunnelResponse)
def get_funnel(_=Depends(require_admin)):
    """
    Platform-wide learner engagement funnel:
    Enrolled → Completed a Lesson → Attempted Assessment → Certified
    """
    from sqlalchemy import text

    with SessionLocal() as db:
        enrolled = db.execute(text(
            "SELECT COUNT(DISTINCT learner_id) FROM lesson_records"
        )).scalar() or 0

        completed_lesson = db.execute(text(
            "SELECT COUNT(DISTINCT learner_id)"
            " FROM lesson_records WHERE completed_at IS NOT NULL"
        )).scalar() or 0

        assessed = db.execute(text(
            "SELECT COUNT(DISTINCT learner_id) FROM assessment_attempts"
        )).scalar() or 0

        certified = db.execute(text(
            "SELECT COUNT(DISTINCT learner_id)"
            " FROM assessment_attempts WHERE passed = 1"
        )).scalar() or 0

    return FunnelResponse(steps=[
        FunnelStep(label="Enrolled",             count=int(enrolled)),
        FunnelStep(label="Completed a Lesson",   count=int(completed_lesson)),
        FunnelStep(label="Attempted Assessment", count=int(assessed)),
        FunnelStep(label="Certified",            count=int(certified)),
    ])
