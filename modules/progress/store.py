"""
modules/progress/store.py -- SQLAlchemy-backed persistence for learner progress.

Receives the SQLAlchemy engine at construction time (injected from main.py)
so it shares the same connection pool and WAL configuration as the ORM layer.
No separate sqlite3.connect() — eliminates the dual-connection problem.
"""

from __future__ import annotations

import time

from sqlalchemy import text
from sqlalchemy.engine import Engine

from .models import LessonRecord, QuizAttempt, WeakTopic


class ProgressStore:
    def __init__(self, engine: Engine) -> None:
        self._engine = engine

    # -- Lesson records ----------------------------------------------------------

    def upsert_lesson_record(self, r: LessonRecord) -> None:
        sql = text("""
        INSERT INTO lesson_records
            (learner_id, course_id, module_idx, lesson_idx, started_at,
             completed_at, checkpoint_score, module_checkpoint_score)
        VALUES (:learner_id, :course_id, :module_idx, :lesson_idx, :started_at,
                :completed_at, :checkpoint_score, :module_checkpoint_score)
        ON CONFLICT(learner_id, course_id, module_idx, lesson_idx) DO UPDATE SET
            completed_at            = COALESCE(excluded.completed_at,            lesson_records.completed_at),
            checkpoint_score        = COALESCE(excluded.checkpoint_score,        lesson_records.checkpoint_score),
            module_checkpoint_score = COALESCE(excluded.module_checkpoint_score, lesson_records.module_checkpoint_score)
        """)
        with self._engine.begin() as conn:
            conn.execute(sql, {
                "learner_id": r.learner_id, "course_id": r.course_id,
                "module_idx": r.module_idx, "lesson_idx": r.lesson_idx,
                "started_at": r.started_at, "completed_at": r.completed_at,
                "checkpoint_score": r.checkpoint_score,
                "module_checkpoint_score": r.module_checkpoint_score,
            })

    def get_lesson_records(self, learner_id: str, course_id: str) -> list[LessonRecord]:
        sql = text(
            "SELECT * FROM lesson_records WHERE learner_id=:lid AND course_id=:cid "
            "ORDER BY module_idx, lesson_idx"
        )
        with self._engine.connect() as conn:
            rows = conn.execute(sql, {"lid": learner_id, "cid": course_id}).fetchall()
        return [LessonRecord(**dict(r._mapping)) for r in rows]

    # -- Quiz attempts -----------------------------------------------------------

    def insert_quiz_attempt(self, a: QuizAttempt) -> None:
        sql = text("""
        INSERT OR IGNORE INTO quiz_attempts
            (id, learner_id, course_id, module_idx, lesson_idx, question_id,
             question_text, learner_answer, correct_answer, is_correct,
             topic_tag, quiz_type, attempted_at)
        VALUES (:id, :learner_id, :course_id, :module_idx, :lesson_idx, :question_id,
                :question_text, :learner_answer, :correct_answer, :is_correct,
                :topic_tag, :quiz_type, :attempted_at)
        """)
        with self._engine.begin() as conn:
            conn.execute(sql, {
                "id": a.id, "learner_id": a.learner_id, "course_id": a.course_id,
                "module_idx": a.module_idx, "lesson_idx": a.lesson_idx,
                "question_id": a.question_id, "question_text": a.question_text,
                "learner_answer": a.learner_answer, "correct_answer": a.correct_answer,
                "is_correct": int(a.is_correct), "topic_tag": a.topic_tag,
                "quiz_type": a.quiz_type, "attempted_at": a.attempted_at,
            })

    # -- Weak topics -------------------------------------------------------------

    def update_weak_topic(
        self, learner_id: str, course_id: str, topic: str, is_correct: bool
    ) -> None:
        miss = 0 if is_correct else 1
        now  = time.time()
        sql = text("""
        INSERT INTO weak_topics (learner_id, course_id, topic, miss_count, total_count, last_seen_at)
        VALUES (:learner_id, :course_id, :topic, :miss, 1, :now)
        ON CONFLICT(learner_id, course_id, topic) DO UPDATE SET
            miss_count   = miss_count  + :miss,
            total_count  = total_count + 1,
            last_seen_at = :now
        """)
        with self._engine.begin() as conn:
            conn.execute(sql, {
                "learner_id": learner_id, "course_id": course_id,
                "topic": topic, "miss": miss, "now": now,
            })

    def get_weak_topics(self, learner_id: str, course_id: str) -> list[WeakTopic]:
        sql = text(
            "SELECT * FROM weak_topics WHERE learner_id=:lid AND course_id=:cid "
            "ORDER BY CAST(miss_count AS REAL) / MAX(total_count, 1) DESC, total_count DESC"
        )
        with self._engine.connect() as conn:
            rows = conn.execute(sql, {"lid": learner_id, "cid": course_id}).fetchall()
        return [WeakTopic(**dict(r._mapping)) for r in rows]
