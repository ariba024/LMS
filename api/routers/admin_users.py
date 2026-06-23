"""
api/routers/admin_users.py -- Admin user management endpoints.

GET    /api/v1/admin/users                       List all user accounts
POST   /api/v1/admin/users                       Create a new user (admin or learner)
PATCH  /api/v1/admin/users/{id}                  Update role / display_name / is_active
POST   /api/v1/admin/users/{id}/reset-password   Force-reset a user's password
DELETE /api/v1/admin/users/{id}                  Deactivate (soft-delete) a user
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import desc

from api.auth import hash_password
from api.db import SessionLocal
from api.dependencies import require_admin
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/admin/users", tags=["Admin — User Management"])


class _UserOut(BaseModel):
    id:           str
    email:        str
    role:         str
    display_name: str | None
    is_active:    bool
    created_at:   float


class _CreateUserRequest(BaseModel):
    email:        EmailStr
    password:     str = Field(min_length=8)
    role:         str = "learner"
    display_name: str | None = None


class _PatchUserRequest(BaseModel):
    role:         str | None = None
    display_name: str | None = None
    is_active:    bool | None = None


class _ResetPasswordRequest(BaseModel):
    new_password: str = Field(min_length=8)


def _to_out(u: UserRow) -> _UserOut:
    return _UserOut(
        id=u.id,
        email=u.email,
        role=u.role,
        display_name=u.display_name,
        is_active=u.is_active,
        created_at=u.created_at,
    )


@router.get("", response_model=list[_UserOut])
def list_users(_=Depends(require_admin)):
    with SessionLocal() as db:
        users = db.query(UserRow).order_by(desc(UserRow.created_at)).all()
        return [_to_out(u) for u in users]


@router.post("", response_model=_UserOut, status_code=201)
def create_user(body: _CreateUserRequest, _=Depends(require_admin)):
    with SessionLocal() as db:
        if db.query(UserRow).filter(UserRow.email == body.email).first():
            raise HTTPException(status_code=409, detail="Email already registered.")
        user = UserRow(
            id=str(uuid.uuid4()),
            email=body.email,
            password_hash=hash_password(body.password),
            role=body.role,
            display_name=body.display_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return _to_out(user)


@router.patch("/{user_id}", response_model=_UserOut)
def update_user(user_id: str, body: _PatchUserRequest, current_user: UserRow = Depends(require_admin)):
    with SessionLocal() as db:
        user = db.get(UserRow, user_id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found.")
        if body.role is not None:
            user.role = body.role
        if body.display_name is not None:
            user.display_name = body.display_name.strip() or None
        if body.is_active is not None:
            if user.id == current_user.id and not body.is_active:
                raise HTTPException(status_code=400, detail="You cannot deactivate your own account.")
            user.is_active = body.is_active
        db.commit()
        db.refresh(user)
        return _to_out(user)


@router.post("/{user_id}/reset-password", response_model=_UserOut)
def reset_password(user_id: str, body: _ResetPasswordRequest, _=Depends(require_admin)):
    with SessionLocal() as db:
        user = db.get(UserRow, user_id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found.")
        user.password_hash = hash_password(body.new_password)
        db.commit()
        db.refresh(user)
        return _to_out(user)


@router.delete("/{user_id}", status_code=204)
def deactivate_user(user_id: str, current_user: UserRow = Depends(require_admin)):
    with SessionLocal() as db:
        user = db.get(UserRow, user_id)
        if user is None:
            raise HTTPException(status_code=404, detail="User not found.")
        if user.id == current_user.id:
            raise HTTPException(status_code=400, detail="You cannot deactivate your own account.")
        user.is_active = False
        db.commit()
