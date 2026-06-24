"""
api/routers/learners.py -- Admin learner management endpoints.

GET /api/v1/learners                      List learners with SQL-aggregated stats + ?q= search
GET /api/v1/learners/{id}                 Summary stats for one learner
GET /api/v1/learners/{id}/courses         Per-course breakdown for one learner
"""

from __future__ import annotations

import time

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import func, distinct, case as sa_case

from api.dependencies import require_admin
from api.db import SessionLocal
from api.models.profile import LearnerProfileRow
from api.models.progress import AssessmentAttemptRow, LessonRecordRow

router = APIRouter(prefix="/api/v1/learners", tags=["Learner Management"])


# ── Helpers ───────────────────────────────────────────────────────────────────

def _derive_name(learner_id: str) -> str:
    local = learner_id.split("@")[0] if "@" in learner_id else learner_id
    return local.replace(".", " ").replace("_", " ").title()


def _fmt_time(secs: float) -> str:
    h = int(secs // 3600)
    m = int((secs % 3600) // 60)
    if h > 0:
        return f"{h}h {m:02d}m"
    return f"{m}m"


def _fmt_ago(ts: float | None) -> str:
    if ts is None:
        return "Never"
    delta = time.time() - ts
    if delta < 3600:
        mins = max(1, int(delta / 60))
        return f"{mins}m ago"
    if delta < 86400:
        return f"{int(delta / 3600)}h ago"
    return f"{int(delta / 86400)}d ago"


def _status(last_ts: float | None) -> str:
    if last_ts is None:
        return "Inactive"
    return "Active" if (time.time() - last_ts) < 7 * 86400 else "Inactive"


# ── Schemas ───────────────────────────────────────────────────────────────────

class LearnerSummary(BaseModel):
    id:          str
    name:        str
    email:       str
    enrolled:    int
    progress:    int    # 0-100
    last_active: str
    time:        str
    assessments: int
    status:      str


class LearnerCourseStat(BaseModel):
    course_id:   str
    title:       str
    total:       int    # lesson rows started
    completed:   int
    percent:     int    # 0-100
    last_active: str
    attempts:    int    # assessment attempts
    best_score:  int    # 0-100; -1 = no attempts


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.get("", response_model=list[LearnerSummary])
def list_learners(
    skip:  int = Query(0,   ge=0,   description="Offset"),
    limit: int = Query(100, ge=1,   le=500, description="Max results"),
    q:     str = Query("",          description="Search by email/ID (partial match)"),
    _=Depends(require_admin),
):
    """
    List every learner who has any activity, with SQL-aggregated stats.
    Replaces the previous full table-scan + Python grouping approach.
    """
    with SessionLocal() as db:
        # ── Lesson aggregation (one row per learner) ─────────────────────────
        lesson_q = db.query(
            LessonRecordRow.learner_id,
            func.count(distinct(LessonRecordRow.course_id)).label("enrolled"),
            func.count(LessonRecordRow.lesson_idx).label("total_lessons"),
            func.sum(
                sa_case((LessonRecordRow.completed_at.isnot(None), 1), else_=0)
            ).label("completed"),
            func.max(LessonRecordRow.started_at).label("last_ts"),
            func.sum(
                sa_case(
                    (LessonRecordRow.completed_at.isnot(None),
                     LessonRecordRow.completed_at - LessonRecordRow.started_at),
                    else_=0,
                )
            ).label("time_secs"),
        ).group_by(LessonRecordRow.learner_id)

        if q:
            lesson_q = lesson_q.filter(LessonRecordRow.learner_id.ilike(f"%{q}%"))

        lesson_rows = {r.learner_id: r for r in lesson_q.all()}

        # ── Assessment count per learner ─────────────────────────────────────
        attempt_q = db.query(
            AssessmentAttemptRow.learner_id,
            func.count(AssessmentAttemptRow.id).label("cnt"),
        ).group_by(AssessmentAttemptRow.learner_id)

        if q:
            attempt_q = attempt_q.filter(
                AssessmentAttemptRow.learner_id.ilike(f"%{q}%")
            )

        attempt_counts = {r.learner_id: r.cnt for r in attempt_q.all()}

        # ── Profiles (only for matched learners) ────────────────────────────
        all_ids = list(set(lesson_rows) | set(attempt_counts))
        profiles: dict = {}
        if all_ids:
            profiles = {
                p.learner_id: p
                for p in db.query(LearnerProfileRow)
                           .filter(LearnerProfileRow.learner_id.in_(all_ids))
                           .all()
            }

    results = []
    for lid in all_ids:
        row     = lesson_rows.get(lid)
        profile = profiles.get(lid)

        name  = (
            profile.display_name if profile and profile.display_name
            else _derive_name(lid)
        )
        email = lid if "@" in lid else ""

        enrolled  = int(row.enrolled  or 0) if row else 0
        total     = int(row.total_lessons or 0) if row else 0
        completed = int(row.completed or 0) if row else 0
        progress  = int(completed / total * 100) if total else 0
        time_secs = float(row.time_secs or 0) if row else 0.0
        last_ts   = float(row.last_ts) if row and row.last_ts else None

        results.append(LearnerSummary(
            id=lid,
            name=name,
            email=email,
            enrolled=enrolled,
            progress=progress,
            last_active=_fmt_ago(last_ts),
            time=_fmt_time(time_secs),
            assessments=attempt_counts.get(lid, 0),
            status=_status(last_ts),
        ))

    sorted_results = sorted(results, key=lambda l: (l.status != "Active", l.name))
    return sorted_results[skip: skip + limit]


@router.get("/{learner_id}/courses", response_model=list[LearnerCourseStat])
def get_learner_courses(learner_id: str, _=Depends(require_admin)):
    """Per-course progress breakdown for one learner."""
    from api.models.courses import CourseScriptRow

    with SessionLocal() as db:
        lesson_rows = (
            db.query(
                LessonRecordRow.course_id,
                func.count(LessonRecordRow.lesson_idx).label("total"),
                func.sum(
                    sa_case((LessonRecordRow.completed_at.isnot(None), 1), else_=0)
                ).label("completed"),
                func.max(LessonRecordRow.started_at).label("last_ts"),
            )
            .filter(LessonRecordRow.learner_id == learner_id)
            .group_by(LessonRecordRow.course_id)
            .all()
        )

        attempt_rows = (
            db.query(
                AssessmentAttemptRow.script_id,
                func.count(AssessmentAttemptRow.id).label("cnt"),
                func.max(AssessmentAttemptRow.score).label("best_score"),
            )
            .filter(AssessmentAttemptRow.learner_id == learner_id)
            .group_by(AssessmentAttemptRow.script_id)
            .all()
        )

        course_ids = {r.course_id for r in lesson_rows}
        scripts: dict[str, str] = {}
        if course_ids:
            scripts = {
                s.script_id: s.course_title
                for s in db.query(CourseScriptRow)
                           .filter(CourseScriptRow.script_id.in_(course_ids))
                           .all()
            }

    attempt_map = {r.script_id: (int(r.cnt), int(r.best_score or 0)) for r in attempt_rows}

    stats = []
    for r in lesson_rows:
        total     = int(r.total or 0)
        completed = int(r.completed or 0)
        cnt, best = attempt_map.get(r.course_id, (0, -1))
        stats.append(LearnerCourseStat(
            course_id=r.course_id,
            title=scripts.get(r.course_id, r.course_id),
            total=total,
            completed=completed,
            percent=int(completed / total * 100) if total else 0,
            last_active=_fmt_ago(float(r.last_ts) if r.last_ts else None),
            attempts=cnt,
            best_score=best if cnt > 0 else -1,
        ))

    return sorted(stats, key=lambda s: s.title)


@router.get("/{learner_id}", response_model=LearnerSummary)
def get_learner(learner_id: str, _=Depends(require_admin)):
    """Summary stats for one learner."""
    with SessionLocal() as db:
        row = (
            db.query(
                func.count(distinct(LessonRecordRow.course_id)).label("enrolled"),
                func.count(LessonRecordRow.lesson_idx).label("total_lessons"),
                func.sum(
                    sa_case((LessonRecordRow.completed_at.isnot(None), 1), else_=0)
                ).label("completed"),
                func.max(LessonRecordRow.started_at).label("last_ts"),
                func.sum(
                    sa_case(
                        (LessonRecordRow.completed_at.isnot(None),
                         LessonRecordRow.completed_at - LessonRecordRow.started_at),
                        else_=0,
                    )
                ).label("time_secs"),
            )
            .filter(LessonRecordRow.learner_id == learner_id)
            .one()
        )
        assessments = (
            db.query(func.count(AssessmentAttemptRow.id))
            .filter(AssessmentAttemptRow.learner_id == learner_id)
            .scalar() or 0
        )
        profile = db.get(LearnerProfileRow, learner_id)

    name  = (
        profile.display_name if profile and profile.display_name
        else _derive_name(learner_id)
    )
    email = learner_id if "@" in learner_id else ""

    total     = int(row.total_lessons or 0)
    completed = int(row.completed or 0)
    progress  = int(completed / total * 100) if total else 0
    last_ts   = float(row.last_ts) if row.last_ts else None

    return LearnerSummary(
        id=learner_id,
        name=name,
        email=email,
        enrolled=int(row.enrolled or 0),
        progress=progress,
        last_active=_fmt_ago(last_ts),
        time=_fmt_time(float(row.time_secs or 0)),
        assessments=int(assessments),
        status=_status(last_ts),
    )
