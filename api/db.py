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
    Create every table that doesn't exist yet, then apply Alembic migrations.
    Safe to call on every startup.
    """
    import api.models  # noqa: F401 — registers all ORM models with Base
    Base.metadata.create_all(bind=engine)
    _run_alembic_migrations()
    db_type = "PostgreSQL" if _is_postgres else "SQLite"
    print(f"[db] {db_type} database initialised (all tables ready).")


def _run_alembic_migrations() -> None:
    """
    Apply pending Alembic migrations.

    Strategy:
    - New install: create_all() already created all tables from ORM models.
      Stamp the DB as 'head' so Alembic knows migrations are already applied.
    - Existing install (pre-Alembic): create_all() is a no-op on existing
      tables; Alembic runs pending migrations (e.g. 001_add_schema_columns).
    - Existing install (with Alembic): run only new pending migrations.

    To add a new column in future: create a new migration with
      alembic revision -m "add_xyz_column"
    and write the upgrade()/downgrade() logic.  No manual ALTER TABLE needed.
    """
    from pathlib import Path as _Path
    from alembic.config import Config
    from alembic import command
    from alembic.runtime.migration import MigrationContext

    _ini = _Path(__file__).resolve().parent.parent / "alembic.ini"
    cfg = Config(str(_ini))

    with engine.connect() as conn:
        ctx = MigrationContext.configure(conn)
        current = ctx.get_current_revision()

    if current is None:
        # No alembic_version row — either a brand-new install or a pre-Alembic
        # install.  In both cases create_all() / old _run_migrations() already
        # applied the schema; stamp as head so migrations don't re-run.
        command.stamp(cfg, "head")
    else:
        command.upgrade(cfg, "head")
