"""
api/dependencies.py -- Shared singleton instances and job tracking.

All heavy objects (embedder, vector_store, pipeline, retrieval_pipeline) are
created once during startup via the FastAPI lifespan and stored in app.state.
Routers receive them through FastAPI's dependency-injection system.

Job tracking now persists to lms.db via SQLAlchemy instead of jobs.json.
"""

from __future__ import annotations

import asyncio
import json
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from api.config import settings
from api.db import get_db
from api.schemas import JobStatus, CourseJobStatus

# ── Auth helpers ──────────────────────────────────────────────────────────────

# Testing bypass — set to False to re-enable real JWT authentication
_DEV_AUTH_BYPASS = True

_bearer = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db=Depends(get_db),
):
    from api.models.users import UserRow

    if _DEV_AUTH_BYPASS:
        return UserRow(id="dev-admin", email="dev@arresto.in", password_hash="", role="admin", is_active=True)

    from jose import JWTError
    from api.auth import decode_token

    _401 = HTTPException(
        status_code=401,
        detail="Not authenticated.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not credentials:
        raise _401
    try:
        payload = decode_token(credentials.credentials)
        if payload.get("type") != "access":
            raise _401
        user_id: str = payload.get("sub", "")
        if not user_id:
            raise _401
    except JWTError:
        raise _401
    user = db.get(UserRow, user_id)
    if user is None or not user.is_active:
        raise _401
    return user


def require_admin(current_user=Depends(get_current_user)):
    if _DEV_AUTH_BYPASS:
        return current_user
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required.")
    return current_user


# Strings that signal the pasted content already has structured quiz items.
# When any marker is found, compat.py routes to the micro-course generator
# (produces items[] with MCQ/Flashcard/TrueFalse) instead of the full pipeline.
_QUIZ_MARKERS: tuple[str, ...] = (
    "Q:", "Q1:", "Q2:", "Q3:",
    "Question:", "Question 1:", "Question 2:",
    "MCQ", "Multiple Choice", "True or False", "True/False",
    "Flashcard", "FLASHCARD",
    "[MCQ]", "[TF]", "[FLASH]",
)


# -- In-memory working objects ------------------------------------------------
# These dataclasses are the in-memory representation of a job while it runs.
# They are written to lms.db on every status change via JobStore._persist_*.

@dataclass
class _UploadJob:
    job_id:         str
    filename:       str
    status:         str = "pending"
    error:          str | None = None
    chunks_created: int | None = None
    started_at:     float = field(default_factory=time.time)
    finished_at:    float | None = None

    def to_schema(self) -> JobStatus:
        elapsed = (
            (self.finished_at or time.time()) - self.started_at
            if self.status != "pending" else None
        )
        return JobStatus(
            job_id=self.job_id,
            status=self.status,
            filename=self.filename,
            error=self.error,
            chunks_created=self.chunks_created,
            processing_seconds=round(elapsed, 1) if elapsed else None,
        )


@dataclass
class _CourseJob:
    job_id:            str
    source_file:       str
    status:            str = "pending"
    error:             str | None  = None
    course_script:     dict | None = None
    started_at:        float = field(default_factory=time.time)
    total_lessons:     int = 0
    completed_lessons: int = 0

    def to_schema(self) -> CourseJobStatus:
        if self.status == "completed":
            progress, step = 100, "Complete"
        elif self.status == "failed":
            progress, step = 0, f"Failed: {self.error or 'unknown error'}"
        elif self.total_lessons > 0:
            progress = int(100 * self.completed_lessons / self.total_lessons)
            step = f"Lesson {self.completed_lessons} of {self.total_lessons}"
        else:
            progress, step = 5, "Generating outline…"
        return CourseJobStatus(
            job_id=self.job_id,
            status=self.status,
            source_file=self.source_file,
            error=self.error,
            course_script=self.course_script,
            total_lessons=self.total_lessons,
            completed_lessons=self.completed_lessons,
            progress=progress,
            step=step,
        )


# -- JobStore -----------------------------------------------------------------

class JobStore:
    """
    Persists upload and course-generation jobs to lms.db (SQLAlchemy).

    An in-memory dict is kept as a read cache so hot polling (Flutter frontend
    checking every second) never hits the database.  Writes always go to the DB.
    """

    def __init__(self) -> None:
        self._uploads: dict[str, _UploadJob] = {}
        self._courses: dict[str, _CourseJob] = {}

    # -- Bootstrap --------------------------------------------------------------

    def load(self) -> None:
        """Read all jobs from DB into the in-memory cache. Called from lifespan after init_db()."""
        try:
            from api.db import SessionLocal
            from api.models.jobs import UploadJobRow, CourseJobRow
            with SessionLocal() as db:
                for row in db.query(UploadJobRow).all():
                    # Any upload job that was still 'processing' when the server
                    # last shut down is a ghost — mark it failed so callers don't
                    # wait on it forever.
                    status = row.status
                    error  = row.error
                    if status == "processing":
                        status = "failed"
                        error  = "Server restarted while job was running. Please try again."
                        row.status = status
                        row.error  = error
                        db.add(row)
                    self._uploads[row.job_id] = _UploadJob(
                        job_id=row.job_id,
                        filename=row.filename,
                        status=status,
                        error=error,
                        chunks_created=row.chunks_created,
                        started_at=row.started_at,
                        finished_at=row.finished_at,
                    )
                for row in db.query(CourseJobRow).all():
                    status = row.status
                    error  = row.error
                    if status == "processing":
                        status = "failed"
                        error  = "Server restarted while job was running. Please try again."
                        row.status = status
                        row.error  = error
                        db.add(row)
                    self._courses[row.job_id] = _CourseJob(
                        job_id=row.job_id,
                        source_file=row.source_file,
                        status=status,
                        error=error,
                        course_script=json.loads(row.course_script_json) if row.course_script_json else None,
                        started_at=row.started_at,
                        total_lessons=row.total_lessons,
                        completed_lessons=row.completed_lessons,
                    )
                db.commit()
        except Exception as exc:
            print(f"[job_store] WARNING: could not load from DB: {exc}")

    def _persist_upload(self, job: _UploadJob) -> None:
        """Upsert one upload job row in the DB."""
        try:
            from api.db import SessionLocal
            from api.models.jobs import UploadJobRow
            with SessionLocal() as db:
                row = db.get(UploadJobRow, job.job_id)
                if row is None:
                    row = UploadJobRow(job_id=job.job_id)
                    db.add(row)
                row.filename       = job.filename
                row.status         = job.status
                row.error          = job.error
                row.chunks_created = job.chunks_created
                row.started_at     = job.started_at
                row.finished_at    = job.finished_at
                db.commit()
        except Exception as exc:
            print(f"[job_store] WARNING: could not persist upload job: {exc}")

    def _persist_course(self, job: _CourseJob) -> None:
        """Upsert one course-generation job row in the DB."""
        try:
            from api.db import SessionLocal
            from api.models.jobs import CourseJobRow
            with SessionLocal() as db:
                row = db.get(CourseJobRow, job.job_id)
                if row is None:
                    row = CourseJobRow(job_id=job.job_id)
                    db.add(row)
                row.source_file        = job.source_file
                row.status             = job.status
                row.error              = job.error
                row.course_script_json = json.dumps(job.course_script) if job.course_script else None
                row.started_at         = job.started_at
                row.total_lessons      = job.total_lessons
                row.completed_lessons  = job.completed_lessons
                db.commit()
        except Exception as exc:
            print(f"[job_store] WARNING: could not persist course job: {exc}")

    # _save() is kept for backward-compat; background workers call it after
    # mutating a job's fields.  It persists ALL dirty jobs.
    def _save(self) -> None:
        for job in self._uploads.values():
            self._persist_upload(job)
        for job in self._courses.values():
            self._persist_course(job)

    # -- Upload jobs ------------------------------------------------------------

    def create_upload(self, filename: str) -> _UploadJob:
        job = _UploadJob(job_id=str(uuid.uuid4()), filename=filename)
        self._uploads[job.job_id] = job
        self._persist_upload(job)
        return job

    def get_upload(self, job_id: str) -> _UploadJob | None:
        # Check local worker cache first (fast path for same-process polling)
        job = self._uploads.get(job_id.strip())
        if job is not None:
            return job
        # Fall back to DB — handles cross-worker reads in multi-worker deployments
        try:
            from api.db import SessionLocal
            from api.models.jobs import UploadJobRow
            with SessionLocal() as db:
                row = db.get(UploadJobRow, job_id.strip())
                if row is None:
                    return None
                return _UploadJob(
                    job_id=row.job_id,
                    filename=row.filename,
                    status=row.status,
                    error=row.error,
                    chunks_created=row.chunks_created,
                    started_at=row.started_at,
                    finished_at=row.finished_at,
                )
        except Exception:
            return None

    # -- Course jobs ------------------------------------------------------------

    def create_course(self, source_file: str) -> _CourseJob:
        job = _CourseJob(job_id=str(uuid.uuid4()), source_file=source_file)
        self._courses[job.job_id] = job
        self._persist_course(job)
        return job

    def get_course(self, job_id: str) -> _CourseJob | None:
        # Check local worker cache first
        job = self._courses.get(job_id.strip())
        if job is not None:
            return job
        # Fall back to DB — handles cross-worker reads
        try:
            from api.db import SessionLocal
            from api.models.jobs import CourseJobRow
            with SessionLocal() as db:
                row = db.get(CourseJobRow, job_id.strip())
                if row is None:
                    return None
                return _CourseJob(
                    job_id=row.job_id,
                    source_file=row.source_file,
                    status=row.status,
                    error=row.error,
                    course_script=json.loads(row.course_script_json) if row.course_script_json else None,
                    started_at=row.started_at,
                    total_lessons=row.total_lessons,
                    completed_lessons=row.completed_lessons,
                )
        except Exception:
            return None

    def list_course_jobs(self) -> list[_CourseJob]:
        """Return all course jobs sorted newest-first. Always reads from DB so all workers see all jobs."""
        try:
            from api.db import SessionLocal
            from api.models.jobs import CourseJobRow
            from sqlalchemy import desc as _desc
            with SessionLocal() as db:
                rows = db.query(CourseJobRow).order_by(_desc(CourseJobRow.started_at)).all()
                return [
                    _CourseJob(
                        job_id=row.job_id,
                        source_file=row.source_file,
                        status=row.status,
                        error=row.error,
                        course_script=json.loads(row.course_script_json) if row.course_script_json else None,
                        started_at=row.started_at,
                        total_lessons=row.total_lessons,
                        completed_lessons=row.completed_lessons,
                    )
                    for row in rows
                ]
        except Exception:
            # Fallback to in-memory cache if DB is unavailable
            return sorted(self._courses.values(), key=lambda j: j.started_at, reverse=True)


# Global singleton
job_store = JobStore()


# -- App-state accessors -------------------------------------------------------

def get_embedder(request: Request):
    return request.app.state.embedder

def get_vector_store(request: Request):
    return request.app.state.vector_store

def get_retrieval_pipeline(request: Request):
    return getattr(request.app.state, "retrieval_pipeline", None)

def get_pipeline(request: Request):
    return request.app.state.pipeline

def get_progress_tracker(request: Request):
    return getattr(request.app.state, "progress_tracker", None)


# -- Pipeline ingestion helper (runs in a thread) ------------------------------

def _sync_ingest(
    job: _UploadJob,
    file_path: Path,
    pipeline: Any,
    retrieval_pipeline: Any = None,
) -> None:
    from modules.content_ingestion.models import Asset, AssetType

    EXTS: dict[str, AssetType] = {
        ".pdf":  AssetType.PDF,
        ".docx": AssetType.DOCX,
        ".pptx": AssetType.PPTX,
        ".txt":  AssetType.TXT,
        ".csv":  AssetType.TXT,
    }

    job.status = "processing"
    try:
        ext = file_path.suffix.lower()
        asset_type = EXTS[ext]
        asset = Asset(
            id=job.job_id,
            file_path=str(file_path),
            asset_type=asset_type,
            original_filename=file_path.name,
            size_bytes=file_path.stat().st_size,
            uploaded_by="api",
        )
        result = pipeline.run(asset)
        job.chunks_created = len(result.chunks)
        job.status = "completed"

        try:
            from api.notification_store import push as _notif
            _notif(
                "admin",
                "Document Uploaded",
                f'"{file_path.name}" ingested successfully ({job.chunks_created} chunks).',
                "📄",
                "document_uploaded",
            )
        except Exception:
            pass

        if retrieval_pipeline is not None and result.chunks:
            try:
                retrieval_pipeline.dual_index(result.chunks)
            except Exception as dual_exc:
                # MiniLM ingestion succeeded so the doc is usable, but advanced
                # retrieval (BGE-m3 hybrid search) won't work for this document.
                # Surface this as a warning in the job response so operators can
                # re-index rather than silently degrading retrieval quality.
                warning = (
                    f"Document ingested (MiniLM) but BGE dual-index failed: {dual_exc}. "
                    "Advanced retrieval may return lower-quality results for this file."
                )
                job.error = warning
                import logging as _logging
                _logging.getLogger("arresto.ingest").warning(warning)

    except Exception as exc:
        job.status = "failed"
        job.error  = str(exc)
    finally:
        job.finished_at = time.time()
        job_store._persist_upload(job)


async def ingest_in_background(
    job: _UploadJob, file_path: Path, pipeline: Any, retrieval_pipeline: Any = None,
) -> None:
    await asyncio.to_thread(_sync_ingest, job, file_path, pipeline, retrieval_pipeline)


# -- Course generation helpers -------------------------------------------------

def _sync_generate_course(
    job:                _CourseJob,
    vector_store:       Any,
    api_key:            str,
    course_title:       str | None,
    target_audience:    str,
    embedder:           Any = None,
    instructions:       str | None = None,
    use_knowledge_base: bool = False,
    course_format:      str = "standard",
    language:           str = "English",
    duration_range:     str = "60-90 minutes",
    user_instructions:  str | None = None,
) -> None:
    from modules.content_ingestion.course_generator import CourseGenerator
    job.status = "processing"
    job_store._persist_course(job)
    try:
        gen = CourseGenerator(
            vector_store=vector_store, api_key=api_key,
            embedder=embedder, model=settings.llm_model,
        )

        if course_format == "custom":
            if not instructions:
                raise ValueError(
                    "course_format='custom' requires an instructions blueprint."
                )
            script = gen.generate_micro_course(
                source_file=job.source_file,
                instructions=instructions,
                course_title=course_title,
                target_audience=target_audience,
                language=language,
            )
        else:
            def _on_lesson_done(done: int, total: int) -> None:
                job.completed_lessons = done
                job.total_lessons     = total
                job_store._persist_course(job)

            script = gen.generate(
                source_file=job.source_file,
                course_title=course_title,
                target_audience=target_audience,
                progress_callback=_on_lesson_done,
                instructions=instructions,
                user_instructions=user_instructions,
                use_knowledge_base=use_knowledge_base,
                language=language,
                duration_range=duration_range,
            )
        job.course_script = script.to_dict()

        import logging as _logging
        import re as _re
        _difficulty = ""
        if instructions:
            _m = _re.search(r"Difficulty level:\s*(\w+)", instructions, _re.IGNORECASE)
            if _m:
                _difficulty = _m.group(1).strip()

        _lib_kwargs = dict(
            script_id=job.job_id,
            source_file=job.source_file,
            course_title=script.course_title,
            target_audience=target_audience,
            course_script=job.course_script,
            instructions=instructions,
            use_knowledge_base=use_knowledge_base,
            language=language,
            difficulty=_difficulty,
            course_format=course_format,
            duration_range=duration_range,
        )
        _lib_saved = False
        try:
            from api.course_library import library as _lib
            _lib.save(**_lib_kwargs)
            _lib_saved = True
        except Exception as _lib_exc:
            _logging.getLogger(__name__).error(
                "course_library.save FAILED for job %s: %s", job.job_id, _lib_exc, exc_info=True,
            )
            # Retry once after a short pause — handles transient SQLite locks
            try:
                time.sleep(1)
                _lib.save(**_lib_kwargs)
                _lib_saved = True
            except Exception as _lib_exc2:
                _logging.getLogger(__name__).error(
                    "course_library.save retry also FAILED for job %s: %s",
                    job.job_id, _lib_exc2, exc_info=True,
                )
                job.error = (
                    f"Course script was generated but could not be saved to the library "
                    f"({_lib_exc2}). The script is still accessible via the job poll endpoint. "
                    f"Please retry generation."
                )

        # Only mark completed if the script reached the library — otherwise the
        # publish step would fail with a silent 404 on the library lookup.
        job.status = "completed" if _lib_saved else "failed"
        job_store._persist_course(job)

        try:
            from api.notification_store import push as _notif
            _notif(
                "admin",
                "Course Generated",
                f'"{script.course_title}" has been generated successfully.',
                "🤖",
                "course_generated",
            )
        except Exception:
            pass
    except Exception as exc:
        job.status = "failed"
        job.error  = str(exc)
        job_store._persist_course(job)


async def generate_course_in_background(
    job: _CourseJob, vector_store: Any, api_key: str, course_title: str | None,
    target_audience: str, embedder: Any = None, instructions: str | None = None,
    use_knowledge_base: bool = False, course_format: str = "standard",
    language: str = "English", duration_range: str = "60-90 minutes",
    user_instructions: str | None = None,
) -> None:
    await asyncio.to_thread(
        _sync_generate_course, job, vector_store, api_key, course_title,
        target_audience, embedder, instructions, use_knowledge_base, course_format,
        language, duration_range, user_instructions,
    )


