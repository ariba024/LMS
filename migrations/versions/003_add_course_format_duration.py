"""Add course_format and duration_range columns to course_scripts table.

Revision ID: 9c4e2a1b8f6d
Revises: 7b2e4f9a1c3d
Create Date: 2026-06-30 00:00:00.000000

"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

revision: str = "9c4e2a1b8f6d"
down_revision: str | None = "7b2e4f9a1c3d"
branch_labels: str | None = None
depends_on: str | None = None


def _existing_columns(table: str) -> set[str]:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        rows = bind.execute(text(f"PRAGMA table_info({table})")).fetchall()
        return {r[1] for r in rows}
    rows = bind.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = :t"
        ),
        {"t": table},
    ).fetchall()
    return {r[0] for r in rows}


def upgrade() -> None:
    existing = _existing_columns("course_scripts")
    if "course_format" not in existing:
        op.add_column(
            "course_scripts",
            sa.Column("course_format", sa.String(), nullable=False, server_default="standard"),
        )
    if "duration_range" not in existing:
        op.add_column(
            "course_scripts",
            sa.Column("duration_range", sa.String(), nullable=False, server_default=""),
        )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return  # SQLite cannot DROP COLUMN easily
    op.drop_column("course_scripts", "duration_range")
    op.drop_column("course_scripts", "course_format")
