from __future__ import annotations

import time
import uuid

from sqlalchemy import Column, Float, Integer, String
from sqlalchemy.orm import Mapped

from api.db import Base


class AttentionEventRow(Base):
    __tablename__ = "attention_events"

    id:          Mapped[str]   = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    learner_id:  Mapped[str]   = Column(String, nullable=False, index=True)
    course_id:   Mapped[str]   = Column(String, nullable=False)
    lesson_id:   Mapped[str]   = Column(String, nullable=False)
    event_type:  Mapped[str]   = Column(String, nullable=False)  # distracted | warning | returned
    pos_secs:    Mapped[int]   = Column(Integer, nullable=False, default=0)
    occurred_at: Mapped[float] = Column(Float, nullable=False, default=time.time)
