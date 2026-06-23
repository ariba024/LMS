"""Add additive columns to course_scripts and video_renders.

These columns were previously added by the hand-rolled _run_migrations()
in api/db.py.  This migration is idempotent: it checks column existence
before applying ALTER TABLE so it is safe to run on databases that already
have the columns (e.g. upgraded from the old startup migration approach).

Revision ID: 3a7f1c2d4e8b
Revises:
Create Date: 2026-06-23 00:00:00.000000

"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

revision: str = "3a7f1c2d4e8b"
down_revision: str | None = None
branch_labels: str | None = None
depends_on: str | None = None


def _existing_columns(table: str) -> set[str]:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        rows = bind.execute(text(f"PRAGMA table_info({table})")).fetchall()
        return {r[1] for r in rows}
    # PostgreSQL / others: use information_schema
    rows = bind.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = :t"
        ),
        {"t": table},
    ).fetchall()
    return {r[0] for r in rows}


def _add_if_missing(
    table: str,
    col_name: str,
    col_type: sa.types.TypeEngine,
    *,
    nullable: bool = True,
    server_default: str | None = None,
) -> None:
    if col_name not in _existing_columns(table):
        op.add_column(
            table,
            sa.Column(
                col_name,
                col_type,
                nullable=nullable,
                server_default=server_default,
            ),
        )


def upgrade() -> None:
    _add_if_missing("course_scripts", "language",                  sa.Text(),    nullable=False, server_default="English")
    _add_if_missing("course_scripts", "difficulty",                sa.Text(),    nullable=False, server_default="")
    _add_if_missing("course_scripts", "published",                 sa.Integer(), nullable=False, server_default="0")
    _add_if_missing("course_scripts", "assessment_num_questions",  sa.Integer(), nullable=False, server_default="5")
    _add_if_missing("course_scripts", "assessment_pass_pct",       sa.Integer(), nullable=False, server_default="70")
    _add_if_missing("course_scripts", "assessment_time_min",       sa.Integer(), nullable=False, server_default="30")
    _add_if_missing("course_scripts", "assessment_retakes",        sa.Integer(), nullable=False, server_default="3")
    _add_if_missing("course_scripts", "assessment_questions_json", sa.Text(),    nullable=True)
    _add_if_missing("video_renders",  "scene_index",               sa.Integer(), nullable=True)
    _add_if_missing("video_renders",  "voice",                     sa.Text(),    nullable=False, server_default="")


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return  # SQLite < 3.35 cannot DROP COLUMN — skip silently
    op.drop_column("video_renders",  "voice")
    op.drop_column("video_renders",  "scene_index")
    op.drop_column("course_scripts", "assessment_questions_json")
    op.drop_column("course_scripts", "assessment_retakes")
    op.drop_column("course_scripts", "assessment_time_min")
    op.drop_column("course_scripts", "assessment_pass_pct")
    op.drop_column("course_scripts", "assessment_num_questions")
    op.drop_column("course_scripts", "published")
    op.drop_column("course_scripts", "difficulty")
    op.drop_column("course_scripts", "language")
