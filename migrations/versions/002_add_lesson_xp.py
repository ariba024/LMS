"""Add lesson_xp column to learner_xp table.

Revision ID: 7b2e4f9a1c3d
Revises: 3a7f1c2d4e8b
Create Date: 2026-06-24 00:00:00.000000

"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy import text

revision: str = "7b2e4f9a1c3d"
down_revision: str | None = "3a7f1c2d4e8b"
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
    if "lesson_xp" not in _existing_columns("learner_xp"):
        op.add_column(
            "learner_xp",
            sa.Column("lesson_xp", sa.Integer(), nullable=False, server_default="0"),
        )


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "sqlite":
        return  # SQLite cannot DROP COLUMN easily
    op.drop_column("learner_xp", "lesson_xp")
