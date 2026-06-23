"""
api/models/users.py -- SQLAlchemy ORM model for learner/admin accounts.
"""

from __future__ import annotations

import time
import uuid

from sqlalchemy import Boolean, Column, Float, String
from sqlalchemy.orm import Mapped

from api.db import Base


class UserRow(Base):
    __tablename__ = "users"

    id:            Mapped[str]       = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email:         Mapped[str]       = Column(String, unique=True, nullable=False, index=True)
    password_hash: Mapped[str]       = Column(String, nullable=False)
    role:          Mapped[str]       = Column(String, nullable=False, default="learner")
    display_name:  Mapped[str | None] = Column(String)
    is_active:     Mapped[bool]      = Column(Boolean, nullable=False, default=True)
    created_at:    Mapped[float]     = Column(Float, nullable=False, default=time.time)
