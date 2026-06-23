"""
api/routers/tickets.py -- Support ticket system.

POST   /api/v1/tickets                  Create a ticket (any authenticated user)
GET    /api/v1/tickets                  List tickets (admin: all; learner: own only)
GET    /api/v1/tickets/{id}             Get ticket + replies
PATCH  /api/v1/tickets/{id}             Update status (admin only)
POST   /api/v1/tickets/{id}/replies     Add a reply (admin or ticket owner)
"""

from __future__ import annotations

import time

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import desc

from api.db import SessionLocal
from api.dependencies import get_current_user
from api.models.tickets import TicketRow, TicketReplyRow
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/tickets", tags=["Support Tickets"])


# ── Schemas ───────────────────────────────────────────────────────────────────

class _CreateTicketRequest(BaseModel):
    subject:     str
    category:    str = "General"
    priority:    str = "Medium"
    description: str


class _PatchTicketRequest(BaseModel):
    status: str


class _AddReplyRequest(BaseModel):
    body: str


class _ReplyOut(BaseModel):
    id:         str
    author:     str
    body:       str
    is_admin:   bool
    created_at: float


class _TicketOut(BaseModel):
    id:           str
    subject:      str
    category:     str
    priority:     str
    status:       str
    learner_id:   str
    learner_name: str
    email:        str
    description:  str
    created_at:   float
    updated_at:   float
    replies:      list[_ReplyOut] = []


def _row_to_out(row: TicketRow) -> _TicketOut:
    return _TicketOut(
        id=row.id,
        subject=row.subject,
        category=row.category,
        priority=row.priority,
        status=row.status,
        learner_id=row.learner_id,
        learner_name=row.learner_name,
        email=row.email,
        description=row.description,
        created_at=row.created_at,
        updated_at=row.updated_at,
        replies=[
            _ReplyOut(
                id=r.id,
                author=r.author,
                body=r.body,
                is_admin=r.is_admin,
                created_at=r.created_at,
            )
            for r in row.replies
        ],
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("", response_model=_TicketOut, status_code=201)
def create_ticket(
    body: _CreateTicketRequest,
    current_user: UserRow = Depends(get_current_user),
):
    """Create a new support ticket for the authenticated user."""
    with SessionLocal() as db:
        ticket = TicketRow(
            subject=body.subject,
            category=body.category,
            priority=body.priority,
            description=body.description,
            learner_id=current_user.email,
            learner_name=current_user.display_name or current_user.email.split("@")[0].title(),
            email=current_user.email,
            status="Open",
        )
        db.add(ticket)
        db.commit()
        db.refresh(ticket)
        return _row_to_out(ticket)


@router.get("", response_model=list[_TicketOut])
def list_tickets(current_user: UserRow = Depends(get_current_user)):
    """Admin sees all tickets; learners see only their own."""
    with SessionLocal() as db:
        q = db.query(TicketRow).order_by(desc(TicketRow.created_at))
        if current_user.role != "admin":
            q = q.filter(TicketRow.learner_id == current_user.email)
        rows = q.all()
        return [_row_to_out(r) for r in rows]


@router.get("/{ticket_id}", response_model=_TicketOut)
def get_ticket(ticket_id: str, current_user: UserRow = Depends(get_current_user)):
    """Get a single ticket with all replies."""
    with SessionLocal() as db:
        row = db.get(TicketRow, ticket_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Ticket not found.")
        if current_user.role != "admin" and row.learner_id != current_user.email:
            raise HTTPException(status_code=403, detail="Access denied.")
        return _row_to_out(row)


@router.patch("/{ticket_id}", response_model=_TicketOut)
def update_ticket_status(
    ticket_id: str,
    body: _PatchTicketRequest,
    current_user: UserRow = Depends(get_current_user),
):
    """Update ticket status (admin only)."""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required.")
    with SessionLocal() as db:
        row = db.get(TicketRow, ticket_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Ticket not found.")
        row.status = body.status
        row.updated_at = time.time()
        db.commit()
        db.refresh(row)
        return _row_to_out(row)


@router.post("/{ticket_id}/replies", response_model=_TicketOut)
def add_reply(
    ticket_id: str,
    body: _AddReplyRequest,
    current_user: UserRow = Depends(get_current_user),
):
    """Add a reply to a ticket. Admin replies move status to In Progress."""
    with SessionLocal() as db:
        row = db.get(TicketRow, ticket_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Ticket not found.")
        if current_user.role != "admin" and row.learner_id != current_user.email:
            raise HTTPException(status_code=403, detail="Access denied.")
        is_admin = current_user.role == "admin"
        author = (
            "Support Team"
            if is_admin
            else (current_user.display_name or current_user.email.split("@")[0].title())
        )
        reply = TicketReplyRow(
            ticket_id=ticket_id,
            author=author,
            body=body.body,
            is_admin=is_admin,
        )
        db.add(reply)
        row.updated_at = time.time()
        if is_admin and row.status == "Open":
            row.status = "In Progress"
        db.commit()
        db.refresh(row)
        return _row_to_out(row)
