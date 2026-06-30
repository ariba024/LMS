"""
api/course_library.py -- Persistent storage for completed course scripts.

Backed by lms.db (SQLAlchemy) instead of individual JSON files.
The public API is identical to the old file-based version so all callers
(routers, dependencies.py, audio router) require zero changes.

Usage
-----
    from api.course_library import library

    entry   = library.save(script_id, source_file, course_title, ...)
    entries = library.list_all()       # index rows, no script body
    record  = library.get(script_id)   # full record including course_script
    record  = library.update(script_id, course_script, course_title)
    existed = library.delete(script_id)
"""

from __future__ import annotations

import json
import time
from typing import Any


class CourseLibrary:
    """Saves and retrieves completed course scripts from lms.db."""

    # -- Public API -----------------------------------------------------------

    def save(
        self,
        script_id:          str,
        source_file:        str,
        course_title:       str,
        target_audience:    str,
        course_script:      dict,
        instructions:       str | None = None,
        use_knowledge_base: bool = False,
        language:           str = "English",
        difficulty:         str = "",
        course_format:      str = "standard",
        duration_range:     str = "",
    ) -> dict:
        """
        Persist a completed course script.
        Returns an index entry dict (identical shape to the old JSON format,
        without the course_script body).
        """
        generated_at = time.time()
        duration_min = course_script.get("estimated_total_duration_min", 0)
        if not duration_min:
            word_count = 0
            for _mod in course_script.get("modules", []):
                for _les in _mod.get("lessons", []):
                    word_count += len((_les.get("narration_script") or "").split())
            for _item in course_script.get("items", []):
                word_count += len((_item.get("narration") or _item.get("narration_script") or "").split())
            duration_min = max(1, round(word_count / 150)) if word_count else 0

        if course_script.get("items"):
            total_lessons = sum(
                1 for item in course_script["items"]
                if item.get("type") in ("slide", "closing_slide")
            )
        else:
            total_lessons = sum(
                len(m.get("lessons", []))
                for m in course_script.get("modules", [])
            )

        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                row = CourseScriptRow(script_id=script_id)
                db.add(row)
            row.source_file            = source_file
            row.course_title           = course_title
            row.target_audience        = target_audience
            row.instructions           = instructions
            row.use_knowledge_base     = use_knowledge_base
            row.generated_at           = generated_at
            row.total_lessons          = total_lessons
            row.estimated_duration_min = duration_min
            row.course_script_json     = json.dumps(course_script, ensure_ascii=False)
            row.language               = language
            row.difficulty             = difficulty
            row.course_format          = course_format
            row.duration_range         = duration_range
            db.commit()
            # Build the return dict from the values we just wrote rather than
            # accessing ORM attributes after commit (expire_on_commit=True marks
            # them stale and a refresh/lazy-load could raise DetachedInstanceError
            # if the underlying connection is recycled).
            entry = {
                "script_id":                script_id,
                "source_file":              source_file,
                "course_title":             course_title,
                "target_audience":          target_audience,
                "instructions":             instructions,
                "use_knowledge_base":       use_knowledge_base,
                "generated_at":             generated_at,
                "total_lessons":            total_lessons,
                "estimated_duration_min":   duration_min,
                "language":                 language,
                "difficulty":               difficulty,
                "course_format":            course_format,
                "duration_range":           duration_range,
                "published":                False,
                "assessment_num_questions": 5,
                "assessment_pass_pct":      70,
                "assessment_time_min":      30,
                "assessment_retakes":       3,
            }

        print(f"[course_library] Saved '{course_title}' ({total_lessons} lessons) -> lms.db")
        return entry

    def list_all(self, published_only: bool = False) -> list[dict]:
        """Return all index entries (no script body), newest first."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        from sqlalchemy import desc
        with SessionLocal() as db:
            q = db.query(CourseScriptRow)
            if published_only:
                q = q.filter(CourseScriptRow.published == True)  # noqa: E712
            rows = q.order_by(desc(CourseScriptRow.generated_at)).all()
            # Build plain dicts while the session is still open; reading row
            # attributes after the with-block exits raises DetachedInstanceError.
            entries = [self._row_to_index_entry(r) for r in rows]
        return entries

    def get(self, script_id: str) -> dict | None:
        """Return the full record including course_script dict, or None."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return None
            # Read all attributes inside the session to avoid DetachedInstanceError.
            entry = self._row_to_index_entry(row)
            entry["course_script"] = json.loads(row.course_script_json) if row.course_script_json else {}
        return entry

    def update(
        self,
        script_id: str,
        course_script: dict,
        course_title: str | None = None,
    ) -> dict | None:
        """Replace the stored course_script (and optionally title). Returns updated record."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return None
            row.course_script_json = json.dumps(course_script, ensure_ascii=False)
            if course_title is not None:
                row.course_title = course_title
            db.commit()
            # Refresh then read inside the session — once the with-block exits
            # the object is detached and attribute access would raise.
            db.refresh(row)
            entry = self._row_to_index_entry(row)
            entry["course_script"] = course_script
        print(f"[course_library] Updated script '{script_id}'.")
        return entry

    def save_assessment_config(
        self,
        script_id:     str,
        num_questions: int = 5,
        pass_pct:      int = 70,
        time_min:      int = 30,
        retakes:       int = 3,
    ) -> bool:
        """Persist assessment configuration for a course. Returns False if not found."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return False
            row.assessment_num_questions = num_questions
            row.assessment_pass_pct      = pass_pct
            row.assessment_time_min      = time_min
            row.assessment_retakes       = retakes
            db.commit()
        return True

    def publish(self, script_id: str, published: bool = True) -> bool:
        """Mark a course as published or draft. Returns False if not found."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return False
            row.published = published
            db.commit()
        return True

    def delete(self, script_id: str) -> bool:
        """Delete a script. Returns True if it existed."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return False
            db.delete(row)
            db.commit()
        return True

    def get_assessment_questions(self, script_id: str) -> list[dict] | None:
        """Return cached assessment questions, or None if not yet generated."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return None
            raw = getattr(row, "assessment_questions_json", None)
            if not raw:
                return None
            return json.loads(raw)

    def save_assessment_questions(self, script_id: str, questions: list[dict]) -> bool:
        """Cache generated assessment questions. Returns False if course not found."""
        from api.db import SessionLocal
        from api.models.courses import CourseScriptRow
        with SessionLocal() as db:
            row = db.get(CourseScriptRow, script_id)
            if row is None:
                return False
            row.assessment_questions_json = json.dumps(questions, ensure_ascii=False)
            db.commit()
        return True

    # -- Internal helpers ------------------------------------------------------

    @staticmethod
    def _row_to_index_entry(row: Any) -> dict:
        """Convert an ORM row to the dict shape the rest of the codebase expects."""
        return {
            "script_id":                   row.script_id,
            "source_file":                 row.source_file,
            "course_title":                row.course_title,
            "target_audience":             row.target_audience,
            "instructions":                row.instructions,
            "use_knowledge_base":          row.use_knowledge_base,
            "generated_at":                row.generated_at,
            "total_lessons":               row.total_lessons,
            "estimated_duration_min":      row.estimated_duration_min,
            "language":                    getattr(row, "language",   "English"),
            "difficulty":                  getattr(row, "difficulty",  ""),
            "course_format":               getattr(row, "course_format",  "standard"),
            "duration_range":              getattr(row, "duration_range", ""),
            "published":                   getattr(row, "published",   False),
            "assessment_num_questions":    getattr(row, "assessment_num_questions", 5),
            "assessment_pass_pct":         getattr(row, "assessment_pass_pct",      70),
            "assessment_time_min":         getattr(row, "assessment_time_min",      30),
            "assessment_retakes":          getattr(row, "assessment_retakes",        3),
            "lesson_count":                row.total_lessons,
            "est_minutes":                 row.estimated_duration_min,
        }


# Singleton used throughout the API
library = CourseLibrary()
