"""
api/db.py -- SQLAlchemy database setup.

Supports two databases transparently:
  - PostgreSQL (default)  — set DATABASE_URL=postgresql://user:pass@host/db
  - SQLite    (dev only)  — set DATABASE_URL=sqlite:///./lms.db

Usage
-----
    from api.db import SessionLocal, get_db, init_db

    # FastAPI dependency (in routers)
    def my_route(db: Session = Depends(get_db)): ...

    # Direct use (in singleton stores)
    with SessionLocal() as db:
        db.add(row)
        db.commit()

    # One-time at startup (in main.py lifespan)
    init_db()
"""

from __future__ import annotations

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, sessionmaker, Session

load_dotenv()
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/arresto_lms")

_is_postgres = DATABASE_URL.startswith(("postgresql://", "postgres://"))

if _is_postgres:
    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )
else:
    # SQLite — single-file, bundled with Python, no installation needed
    engine = create_engine(
        DATABASE_URL,
        connect_args={"check_same_thread": False},
        pool_pre_ping=True,
    )

    @event.listens_for(engine, "connect")
    def _set_wal_mode(dbapi_conn, _conn_rec):
        dbapi_conn.execute("PRAGMA journal_mode=WAL")
        dbapi_conn.execute("PRAGMA foreign_keys=ON")


SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI dependency — yields a DB session and always closes it."""
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """
    Create every table that doesn't exist yet, then run additive column migrations.
    Safe to call on every startup — CREATE TABLE IF NOT EXISTS semantics.
    """
    import api.models  # noqa: F401 — registers all ORM models with Base
    Base.metadata.create_all(bind=engine)
    _run_migrations()
    db_type = "PostgreSQL" if _is_postgres else "SQLite"
    print(f"[db] {db_type} database initialised (all tables ready).")


# ---------------------------------------------------------------------------
# Schema migrations
#
# To add a new column: append a tuple to _ADDITIVE_COLS — no other file changes.
# Format: (table, col_name, sql_type, default_sql, nullable)
#
# Each migration is idempotent: SQLite uses PRAGMA table_info to skip existing
# columns; PostgreSQL uses ADD COLUMN IF NOT EXISTS.
# ---------------------------------------------------------------------------

_ADDITIVE_COLS: list[tuple[str, str, str, str, bool]] = [
    # table               col_name                      sql_type   default_sql  nullable
    ("course_scripts",    "language",                   "TEXT",    "'English'", False),
    ("course_scripts",    "difficulty",                 "TEXT",    "''",        False),
    ("course_scripts",    "published",                  "INTEGER", "false",     False),
    ("course_scripts",    "assessment_num_questions",   "INTEGER", "5",         False),
    ("course_scripts",    "assessment_pass_pct",        "INTEGER", "70",        False),
    ("course_scripts",    "assessment_time_min",        "INTEGER", "30",        False),
    ("course_scripts",    "assessment_retakes",         "INTEGER", "3",         False),
    ("course_scripts",    "assessment_questions_json",  "TEXT",    "NULL",      True),
    ("video_renders",     "scene_index",                "INTEGER", "NULL",      True),
    ("video_renders",     "voice",                      "TEXT",    "''",        False),
]


def _run_migrations() -> None:
    """Apply all pending additive column migrations."""
    from sqlalchemy import text

    with engine.connect() as conn:
        if _is_postgres:
            for table, col, typ, default, nullable in _ADDITIVE_COLS:
                pg_type = "BOOLEAN" if typ == "INTEGER" and col == "published" else typ
                null_clause = "" if nullable else f" NOT NULL DEFAULT {default}"
                try:
                    conn.execute(text(
                        f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS "
                        f"{col} {pg_type}{null_clause}"
                    ))
                    conn.commit()
                except Exception:
                    conn.rollback()
        else:
            # Cache PRAGMA results per table to avoid redundant round-trips
            table_cols: dict[str, set[str]] = {}
            for table, col, typ, default, nullable in _ADDITIVE_COLS:
                if table not in table_cols:
                    result = conn.execute(text(f"PRAGMA table_info({table})"))
                    table_cols[table] = {row[1] for row in result}
                if col not in table_cols[table]:
                    if nullable:
                        conn.execute(text(
                            f"ALTER TABLE {table} ADD COLUMN {col} {typ}"
                        ))
                    else:
                        conn.execute(text(
                            f"ALTER TABLE {table} ADD COLUMN "
                            f"{col} {typ} NOT NULL DEFAULT {default}"
                        ))
                    table_cols[table].add(col)
            conn.commit()
