"""
api/routers/attention_events.py — Attention event persistence and reporting.

POST /api/v1/attention/events              Log one event (learner, fire-and-forget)
GET  /api/v1/attention/summary/{learner_id} Per-lesson focus summary (admin or own learner)
"""

from __future__ import annotations

import time
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func

from api.db import SessionLocal
from api.dependencies import get_current_user
from api.models.attention import AttentionEventRow
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/attention", tags=["Attention"])


class _LogEventRequest(BaseModel):
    course_id:  str
    lesson_id:  str
    event_type: str  # distracted | warning | returned
    pos_secs:   int = 0


class _LessonAttentionStat(BaseModel):
    lesson_id:        str
    distracted_count: int
    warning_count:    int
    returned_count:   int
    focus_score:      float  # 0–100: returned/distracted ratio


class _AttentionSummary(BaseModel):
    learner_id: str
    lessons:    list[_LessonAttentionStat]


@router.post("/events", status_code=204)
def log_event(
    body: _LogEventRequest,
    current_user: UserRow = Depends(get_current_user),
) -> None:
    """Persist one attention event from the Flutter lesson player."""
    with SessionLocal() as db:
        db.add(AttentionEventRow(
            id=str(uuid.uuid4()),
            learner_id=current_user.email,
            course_id=body.course_id,
            lesson_id=body.lesson_id,
            event_type=body.event_type,
            pos_secs=body.pos_secs,
            occurred_at=time.time(),
        ))
        db.commit()


@router.get("/summary/{learner_id}", response_model=_AttentionSummary)
def get_summary(
    learner_id: str,
    current_user: UserRow = Depends(get_current_user),
) -> _AttentionSummary:
    """Return per-lesson attention stats for a learner (admin or own learner)."""
    if current_user.role != "admin" and current_user.email != learner_id:
        raise HTTPException(status_code=403, detail="Admin access required.")

    with SessionLocal() as db:
        rows = (
            db.query(
                AttentionEventRow.lesson_id,
                AttentionEventRow.event_type,
                func.count(AttentionEventRow.id).label("cnt"),
            )
            .filter(AttentionEventRow.learner_id == learner_id)
            .group_by(AttentionEventRow.lesson_id, AttentionEventRow.event_type)
            .all()
        )

    lesson_map: dict[str, dict[str, int]] = {}
    for lesson_id, event_type, cnt in rows:
        if lesson_id not in lesson_map:
            lesson_map[lesson_id] = {"distracted": 0, "warning": 0, "returned": 0}
        if event_type in lesson_map[lesson_id]:
            lesson_map[lesson_id][event_type] = cnt

    lessons = [
        _LessonAttentionStat(
            lesson_id=lid,
            distracted_count=counts["distracted"],
            warning_count=counts["warning"],
            returned_count=counts["returned"],
            focus_score=round(
                min(100.0, 100.0 * counts["returned"] / max(1, counts["distracted"])),
                1,
            ),
        )
        for lid, counts in sorted(lesson_map.items())
    ]
    return _AttentionSummary(learner_id=learner_id, lessons=lessons)
