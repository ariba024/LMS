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
from api.models.progress import LessonRecordRow
from api.models.renders import VideoRenderRow

router = APIRouter(prefix="/api/v1/analytics", tags=["Analytics"])

_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
           "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


class MonthlyActivity(BaseModel):
    month: str
    count: int


class OverviewResponse(BaseModel):
    total_courses:      int
    total_videos:       int
    total_learners:     int
    active_learners:    int
    learner_activity:   list[MonthlyActivity]
    style_distribution: dict[str, int]


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

        # Monthly unique active learners for the past 6 months.
        # Month boundaries are computed in Python (avoids dialect-specific date
        # functions), then 6 small indexed time-window queries are fired.
        now = datetime.now(tz=timezone.utc)
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

    return OverviewResponse(
        total_courses=total_courses,
        total_videos=total_videos,
        total_learners=total_learners,
        active_learners=active_learners,
        learner_activity=activity,
        style_distribution=style_dist,
    )
