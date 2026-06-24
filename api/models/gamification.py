"""ORM models for the gamification module."""

from __future__ import annotations

from sqlalchemy import Boolean, Column, Float, Integer, String, Text
from sqlalchemy.orm import Mapped

from api.db import Base


class DailyQuestionRow(Base):
    """One AI-generated question per course per calendar date."""

    __tablename__ = "daily_questions"

    id: Mapped[str] = Column(String, primary_key=True)          # "{course_id}:{date}"
    course_id: Mapped[str] = Column(String, nullable=False, index=True)
    date_str: Mapped[str] = Column(String, nullable=False)      # "2026-06-23"
    question_text: Mapped[str] = Column(Text, nullable=False)
    option_a: Mapped[str] = Column(Text, nullable=False)
    option_b: Mapped[str] = Column(Text, nullable=False)
    option_c: Mapped[str] = Column(Text, nullable=False)
    option_d: Mapped[str] = Column(Text, nullable=False)
    correct_index: Mapped[int] = Column(Integer, nullable=False)  # 0–3
    explanation: Mapped[str] = Column(Text, nullable=False)
    xp_reward: Mapped[int] = Column(Integer, nullable=False, default=20)
    created_at: Mapped[float] = Column(Float, nullable=False)


class DailyQuestionAttemptRow(Base):
    """Learner's single attempt at a daily question."""

    __tablename__ = "daily_question_attempts"

    id: Mapped[str] = Column(String, primary_key=True)          # "{learner_id}:{question_id}"
    learner_id: Mapped[str] = Column(String, nullable=False, index=True)
    question_id: Mapped[str] = Column(String, nullable=False, index=True)
    course_id: Mapped[str] = Column(String, nullable=False, index=True)
    selected_index: Mapped[int] = Column(Integer, nullable=False)
    is_correct: Mapped[bool] = Column(Boolean, nullable=False)
    xp_earned: Mapped[int] = Column(Integer, nullable=False, default=0)
    attempted_at: Mapped[float] = Column(Float, nullable=False)


class HazardSessionRow(Base):
    """An AI-generated Spot-the-Hazard game session for a course."""

    __tablename__ = "hazard_sessions"

    id: Mapped[str] = Column(String, primary_key=True)
    course_id: Mapped[str] = Column(String, nullable=False, index=True)
    title: Mapped[str] = Column(String, nullable=False)
    scene_description: Mapped[str] = Column(Text, nullable=False)
    image_url: Mapped[str | None] = Column(Text)            # HeyGen-generated image URL
    hazard_regions_json: Mapped[str] = Column(Text, nullable=False)  # JSON list
    quiz_questions_json: Mapped[str] = Column(Text, nullable=False)  # JSON list
    xp_reward: Mapped[int] = Column(Integer, nullable=False, default=100)
    created_at: Mapped[float] = Column(Float, nullable=False)
    active: Mapped[bool] = Column(Boolean, nullable=False, default=True)


class HazardAttemptRow(Base):
    """Learner's play-through result for one hazard session."""

    __tablename__ = "hazard_attempts"

    id: Mapped[str] = Column(String, primary_key=True)
    learner_id: Mapped[str] = Column(String, nullable=False, index=True)
    session_id: Mapped[str] = Column(String, nullable=False, index=True)
    course_id: Mapped[str] = Column(String, nullable=False, index=True)
    hazards_found: Mapped[int] = Column(Integer, nullable=False, default=0)
    total_hazards: Mapped[int] = Column(Integer, nullable=False, default=0)
    quiz_correct: Mapped[int] = Column(Integer, nullable=False, default=0)
    quiz_total: Mapped[int] = Column(Integer, nullable=False, default=0)
    xp_earned: Mapped[int] = Column(Integer, nullable=False, default=0)
    time_taken_secs: Mapped[int] = Column(Integer, nullable=False, default=0)
    attempted_at: Mapped[float] = Column(Float, nullable=False)


class LearnerXPRow(Base):
    """Aggregate XP per learner per course — updated after each gamification activity."""

    __tablename__ = "learner_xp"

    id: Mapped[str] = Column(String, primary_key=True)          # "{learner_id}:{course_id}"
    learner_id: Mapped[str] = Column(String, nullable=False, index=True)
    course_id: Mapped[str] = Column(String, nullable=False, index=True)
    display_name: Mapped[str] = Column(String, nullable=False, default="Learner")
    total_xp: Mapped[int] = Column(Integer, nullable=False, default=0)
    daily_q_xp: Mapped[int] = Column(Integer, nullable=False, default=0)
    hazard_xp: Mapped[int] = Column(Integer, nullable=False, default=0)
    lesson_xp: Mapped[int] = Column(Integer, nullable=False, default=0)
    daily_q_streak: Mapped[int] = Column(Integer, nullable=False, default=0)
    last_daily_q_date: Mapped[str | None] = Column(String)
    updated_at: Mapped[float] = Column(Float, nullable=False, default=0.0)
