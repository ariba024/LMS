"""
api/routers/gamification.py

Gamification endpoints:

  GET  /api/v1/gamification/daily-question/{course_id}
  POST /api/v1/gamification/daily-question/{course_id}/attempt
  GET  /api/v1/gamification/hazard-sessions/{course_id}
  POST /api/v1/gamification/hazard-sessions/{course_id}/generate  (admin)
  POST /api/v1/gamification/hazard-attempt
  GET  /api/v1/gamification/leaderboard/{course_id}
  GET  /api/v1/gamification/profile/{learner_id}/{course_id}
"""

from __future__ import annotations

import asyncio
import json
import logging
import time
import uuid
from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from api.config import settings
from api.db import get_db
from api.models.courses import CourseScriptRow
from api.models.gamification import (
    DailyQuestionAttemptRow,
    DailyQuestionRow,
    HazardAttemptRow,
    HazardSessionRow,
    LearnerXPRow,
)
from api.models.profile import LearnerProfileRow

router = APIRouter(prefix="/api/v1/gamification", tags=["Gamification"])
logger = logging.getLogger("arresto.gamification")


# ── helpers ───────────────────────────────────────────────────────────────────

def _today() -> str:
    return date.today().isoformat()


def _now() -> float:
    return time.time()


def _get_course_content(course_id: str, db: Session) -> tuple[str, str]:
    """Return (course_title, content_text) or raise 404."""
    row = db.query(CourseScriptRow).filter(CourseScriptRow.script_id == course_id).first()
    if not row:
        raise HTTPException(status_code=404, detail=f"Course '{course_id}' not found.")

    script = json.loads(row.course_script_json)
    title = row.course_title

    # Concatenate all lesson narrations into one content blob
    parts: list[str] = []
    for mod in script.get("modules", []):
        for les in mod.get("lessons", []):
            narration = les.get("narration_script", "").strip()
            if narration:
                parts.append(narration)

    # Fallback: use the raw script JSON excerpt
    content = "\n\n".join(parts) or json.dumps(script)[:8000]
    return title, content


def _get_or_create_xp(learner_id: str, course_id: str, db: Session) -> LearnerXPRow:
    xp_id = f"{learner_id}:{course_id}"
    row = db.query(LearnerXPRow).filter(LearnerXPRow.id == xp_id).first()
    if not row:
        # Try to get display name from profile
        profile = db.query(LearnerProfileRow).filter(
            LearnerProfileRow.learner_id == learner_id
        ).first()
        display_name = profile.display_name if profile else learner_id

        row = LearnerXPRow(
            id=xp_id,
            learner_id=learner_id,
            course_id=course_id,
            display_name=display_name,
            total_xp=0,
            daily_q_xp=0,
            hazard_xp=0,
            daily_q_streak=0,
            last_daily_q_date=None,
            updated_at=_now(),
        )
        db.add(row)
        db.flush()
    return row


# ── Daily Question ─────────────────────────────────────────────────────────────

class DailyQuestionOut(BaseModel):
    question_id: str
    question_text: str
    options: list[str]
    xp_reward: int
    already_attempted: bool
    selected_index: int | None = None
    is_correct: bool | None = None
    correct_index: int | None = None
    explanation: str | None = None


@router.get("/daily-question/{course_id}", response_model=DailyQuestionOut)
async def get_daily_question(
    course_id: str,
    learner_id: str = "anonymous",
    db: Session = Depends(get_db),
):
    """Get (or generate) today's question for a course."""
    today = _today()
    q_id = f"{course_id}:{today}"

    row = db.query(DailyQuestionRow).filter(DailyQuestionRow.id == q_id).first()

    if not row:
        if not settings.anthropic_api_key:
            raise HTTPException(
                status_code=503,
                detail="ANTHROPIC_API_KEY not set — daily question generation unavailable.",
            )
        title, content = _get_course_content(course_id, db)

        from modules.gamification.question_generator import generate_daily_question
        try:
            q_data = await asyncio.to_thread(
                generate_daily_question, title, content, today
            )
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Question generation failed: {exc}")

        row = DailyQuestionRow(
            id=q_id,
            course_id=course_id,
            date_str=today,
            question_text=q_data["question"],
            option_a=q_data["options"][0],
            option_b=q_data["options"][1],
            option_c=q_data["options"][2],
            option_d=q_data["options"][3],
            correct_index=q_data["correct_index"],
            explanation=q_data["explanation"],
            xp_reward=20,
            created_at=_now(),
        )
        db.add(row)
        db.commit()
        db.refresh(row)

    # Check if this learner already attempted today
    attempt_id = f"{learner_id}:{q_id}"
    attempt = db.query(DailyQuestionAttemptRow).filter(
        DailyQuestionAttemptRow.id == attempt_id
    ).first()

    if attempt:
        return DailyQuestionOut(
            question_id=q_id,
            question_text=row.question_text,
            options=[row.option_a, row.option_b, row.option_c, row.option_d],
            xp_reward=row.xp_reward,
            already_attempted=True,
            selected_index=attempt.selected_index,
            is_correct=attempt.is_correct,
            correct_index=row.correct_index,
            explanation=row.explanation,
        )

    return DailyQuestionOut(
        question_id=q_id,
        question_text=row.question_text,
        options=[row.option_a, row.option_b, row.option_c, row.option_d],
        xp_reward=row.xp_reward,
        already_attempted=False,
    )


class SubmitDailyQRequest(BaseModel):
    learner_id: str
    selected_index: int


class SubmitDailyQResponse(BaseModel):
    is_correct: bool
    correct_index: int
    explanation: str
    xp_earned: int
    streak: int


@router.post("/daily-question/{course_id}/attempt", response_model=SubmitDailyQResponse)
def submit_daily_question(
    course_id: str,
    body: SubmitDailyQRequest,
    db: Session = Depends(get_db),
):
    """Submit an answer to today's daily question."""
    today = _today()
    q_id = f"{course_id}:{today}"
    attempt_id = f"{body.learner_id}:{q_id}"

    row = db.query(DailyQuestionRow).filter(DailyQuestionRow.id == q_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="No daily question for this course today.")

    existing = db.query(DailyQuestionAttemptRow).filter(
        DailyQuestionAttemptRow.id == attempt_id
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Already attempted today's question.")

    is_correct = body.selected_index == row.correct_index
    xp = row.xp_reward if is_correct else 5  # 5 XP participation reward

    attempt = DailyQuestionAttemptRow(
        id=attempt_id,
        learner_id=body.learner_id,
        question_id=q_id,
        course_id=course_id,
        selected_index=body.selected_index,
        is_correct=is_correct,
        xp_earned=xp,
        attempted_at=_now(),
    )
    db.add(attempt)

    xp_row = _get_or_create_xp(body.learner_id, course_id, db)

    # Update streak
    prev_date = xp_row.last_daily_q_date
    yesterday = (
        datetime.fromtimestamp(_now(), tz=timezone.utc)
        .date()
        .replace(day=datetime.fromtimestamp(_now(), tz=timezone.utc).date().day - 1)
        .isoformat()
        if _now() > 86400
        else None
    )
    if prev_date == today:
        pass  # Already counted today (shouldn't reach here due to 409 above)
    elif prev_date and (
        (date.fromisoformat(today) - date.fromisoformat(prev_date)).days == 1
    ):
        xp_row.daily_q_streak += 1
    else:
        xp_row.daily_q_streak = 1

    xp_row.last_daily_q_date = today
    xp_row.daily_q_xp += xp
    xp_row.total_xp += xp
    xp_row.updated_at = _now()

    db.commit()

    return SubmitDailyQResponse(
        is_correct=is_correct,
        correct_index=row.correct_index,
        explanation=row.explanation,
        xp_earned=xp,
        streak=xp_row.daily_q_streak,
    )


# ── Hazard Sessions ────────────────────────────────────────────────────────────

class HazardRegionOut(BaseModel):
    label: str
    note: str
    cx: float
    cy: float
    r: float


class QuizQuestionOut(BaseModel):
    question: str
    options: list[str]
    correct_index: int
    explanation: str


class HazardSessionOut(BaseModel):
    session_id: str
    course_id: str
    title: str
    scene_description: str
    image_url: str | None
    hazard_regions: list[HazardRegionOut]
    quiz_questions: list[QuizQuestionOut]
    xp_reward: int


@router.get("/hazard-sessions/{course_id}", response_model=list[HazardSessionOut])
def get_hazard_sessions(
    course_id: str,
    db: Session = Depends(get_db),
):
    """Return active hazard sessions for a course. Returns empty list if none exist yet."""
    rows = (
        db.query(HazardSessionRow)
        .filter(HazardSessionRow.course_id == course_id, HazardSessionRow.active == True)
        .order_by(HazardSessionRow.created_at)
        .all()
    )
    return [_session_row_to_out(r) for r in rows]


def _session_row_to_out(row: HazardSessionRow) -> HazardSessionOut:
    regions = json.loads(row.hazard_regions_json)
    questions = json.loads(row.quiz_questions_json)
    return HazardSessionOut(
        session_id=row.id,
        course_id=row.course_id,
        title=row.title,
        scene_description=row.scene_description,
        image_url=row.image_url,
        hazard_regions=[HazardRegionOut(**r) for r in regions],
        quiz_questions=[QuizQuestionOut(**q) for q in questions],
        xp_reward=row.xp_reward,
    )


@router.post("/hazard-sessions/{course_id}/generate", response_model=list[HazardSessionOut])
async def generate_hazard_sessions(
    course_id: str,
    db: Session = Depends(get_db),
):
    """
    (Admin) Generate 3 new Spot-the-Hazard sessions for a course using AI.
    Deactivates any existing sessions for this course first.
    Requires ANTHROPIC_API_KEY; HEYGEN_API_KEY is optional (enables real images).
    """
    if not settings.anthropic_api_key:
        raise HTTPException(
            status_code=503,
            detail="ANTHROPIC_API_KEY not set — hazard session generation unavailable.",
        )

    title, content = _get_course_content(course_id, db)

    from modules.gamification.hazard_generator import (
        generate_hazard_scenarios,
        generate_session_with_image,
    )

    try:
        scenarios = await asyncio.to_thread(generate_hazard_scenarios, title, content)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Hazard generation failed: {exc}")

    # Deactivate old sessions
    db.query(HazardSessionRow).filter(HazardSessionRow.course_id == course_id).update(
        {"active": False}
    )

    new_rows: list[HazardSessionRow] = []
    for scenario in scenarios[:3]:
        # Try to generate image via HeyGen (may return None)
        scenario_with_img = await asyncio.to_thread(generate_session_with_image, scenario)

        row = HazardSessionRow(
            id=str(uuid.uuid4()),
            course_id=course_id,
            title=scenario_with_img.get("title", "Hazard Scenario"),
            scene_description=scenario_with_img.get("scene_description", ""),
            image_url=scenario_with_img.get("image_url"),
            hazard_regions_json=json.dumps(scenario_with_img.get("hazard_regions", [])),
            quiz_questions_json=json.dumps(scenario_with_img.get("quiz_questions", [])),
            xp_reward=100,
            created_at=_now(),
            active=True,
        )
        db.add(row)
        new_rows.append(row)

    db.commit()
    for r in new_rows:
        db.refresh(r)

    return [_session_row_to_out(r) for r in new_rows]


# ── Hazard Attempt ─────────────────────────────────────────────────────────────

class HazardAttemptRequest(BaseModel):
    learner_id: str
    session_id: str
    course_id: str
    hazards_found: int
    total_hazards: int
    quiz_correct: int
    quiz_total: int
    time_taken_secs: int


class HazardAttemptResponse(BaseModel):
    xp_earned: int
    total_xp: int


@router.post("/hazard-attempt", response_model=HazardAttemptResponse)
def submit_hazard_attempt(
    body: HazardAttemptRequest,
    db: Session = Depends(get_db),
):
    """Submit a completed Spot-the-Hazard game result and award XP."""
    # XP formula: 60 base * (found/total) + 10 per quiz correct + speed bonus
    spot_xp = int(60 * body.hazards_found / max(body.total_hazards, 1))
    quiz_xp = body.quiz_correct * 10
    speed_bonus = max(0, 30 - body.time_taken_secs // 10)  # up to 30 bonus for speed
    xp = spot_xp + quiz_xp + speed_bonus

    attempt = HazardAttemptRow(
        id=str(uuid.uuid4()),
        learner_id=body.learner_id,
        session_id=body.session_id,
        course_id=body.course_id,
        hazards_found=body.hazards_found,
        total_hazards=body.total_hazards,
        quiz_correct=body.quiz_correct,
        quiz_total=body.quiz_total,
        xp_earned=xp,
        time_taken_secs=body.time_taken_secs,
        attempted_at=_now(),
    )
    db.add(attempt)

    xp_row = _get_or_create_xp(body.learner_id, body.course_id, db)
    xp_row.hazard_xp += xp
    xp_row.total_xp += xp
    xp_row.updated_at = _now()
    db.commit()

    return HazardAttemptResponse(xp_earned=xp, total_xp=xp_row.total_xp)


# ── Leaderboard ────────────────────────────────────────────────────────────────

class LeaderboardEntry(BaseModel):
    rank: int
    learner_id: str
    display_name: str
    total_xp: int
    daily_q_xp: int
    hazard_xp: int
    daily_q_streak: int


@router.get("/leaderboard/{course_id}", response_model=list[LeaderboardEntry])
def get_leaderboard(
    course_id: str,
    limit: int = 20,
    db: Session = Depends(get_db),
):
    """Return top learners for a course ranked by total XP."""
    rows = (
        db.query(LearnerXPRow)
        .filter(LearnerXPRow.course_id == course_id)
        .order_by(LearnerXPRow.total_xp.desc())
        .limit(limit)
        .all()
    )
    return [
        LeaderboardEntry(
            rank=i + 1,
            learner_id=r.learner_id,
            display_name=r.display_name,
            total_xp=r.total_xp,
            daily_q_xp=r.daily_q_xp,
            hazard_xp=r.hazard_xp,
            daily_q_streak=r.daily_q_streak,
        )
        for i, r in enumerate(rows)
    ]


# ── Profile ────────────────────────────────────────────────────────────────────

class GamificationProfile(BaseModel):
    learner_id: str
    course_id: str
    display_name: str
    total_xp: int
    daily_q_xp: int
    hazard_xp: int
    daily_q_streak: int
    rank: int | None


@router.get("/profile/{learner_id}/{course_id}", response_model=GamificationProfile)
def get_gamification_profile(
    learner_id: str,
    course_id: str,
    db: Session = Depends(get_db),
):
    """Return a learner's gamification stats for a course."""
    xp_id = f"{learner_id}:{course_id}"
    row = db.query(LearnerXPRow).filter(LearnerXPRow.id == xp_id).first()

    if not row:
        return GamificationProfile(
            learner_id=learner_id,
            course_id=course_id,
            display_name=learner_id,
            total_xp=0,
            daily_q_xp=0,
            hazard_xp=0,
            daily_q_streak=0,
            rank=None,
        )

    # Compute rank
    higher_count = (
        db.query(LearnerXPRow)
        .filter(
            LearnerXPRow.course_id == course_id,
            LearnerXPRow.total_xp > row.total_xp,
        )
        .count()
    )
    rank = higher_count + 1

    return GamificationProfile(
        learner_id=learner_id,
        course_id=course_id,
        display_name=row.display_name,
        total_xp=row.total_xp,
        daily_q_xp=row.daily_q_xp,
        hazard_xp=row.hazard_xp,
        daily_q_streak=row.daily_q_streak,
        rank=rank,
    )
