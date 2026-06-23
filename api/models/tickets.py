"""ORM models for the support ticket system."""

from __future__ import annotations

import time
import uuid

from sqlalchemy import Boolean, Column, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, relationship

from api.db import Base


class TicketRow(Base):
    __tablename__ = "tickets"

    id:           Mapped[str]   = Column(String, primary_key=True, default=lambda: f"TK-{str(uuid.uuid4())[:8].upper()}")
    subject:      Mapped[str]   = Column(String, nullable=False)
    category:     Mapped[str]   = Column(String, nullable=False, default="General")
    priority:     Mapped[str]   = Column(String, nullable=False, default="Medium")
    status:       Mapped[str]   = Column(String, nullable=False, default="Open")
    learner_id:   Mapped[str]   = Column(String, nullable=False, index=True)
    learner_name: Mapped[str]   = Column(String, nullable=False, default="")
    email:        Mapped[str]   = Column(String, nullable=False, default="")
    description:  Mapped[str]   = Column(Text,   nullable=False, default="")
    created_at:   Mapped[float] = Column(Float,  nullable=False, default=time.time)
    updated_at:   Mapped[float] = Column(Float,  nullable=False, default=time.time)

    replies: Mapped[list[TicketReplyRow]] = relationship(
        "TicketReplyRow",
        back_populates="ticket",
        cascade="all, delete-orphan",
        order_by="TicketReplyRow.created_at",
    )


class TicketReplyRow(Base):
    __tablename__ = "ticket_replies"

    id:         Mapped[str]   = Column(String,  primary_key=True, default=lambda: str(uuid.uuid4()))
    ticket_id:  Mapped[str]   = Column(String,  ForeignKey("tickets.id", ondelete="CASCADE"), nullable=False, index=True)
    author:     Mapped[str]   = Column(String,  nullable=False)
    body:       Mapped[str]   = Column(Text,    nullable=False)
    is_admin:   Mapped[bool]  = Column(Boolean, nullable=False, default=False)
    created_at: Mapped[float] = Column(Float,   nullable=False, default=time.time)

    ticket: Mapped[TicketRow] = relationship("TicketRow", back_populates="replies")
