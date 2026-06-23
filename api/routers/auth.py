"""
api/routers/auth.py -- Authentication endpoints.

POST /api/v1/auth/register   Create a new learner account
POST /api/v1/auth/login      Email + password → access + refresh tokens
POST /api/v1/auth/refresh    Swap a refresh token for a new pair of tokens
GET  /api/v1/auth/me         Return the authenticated user's profile
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException
from jose import JWTError
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from api import auth as _auth
from api.db import get_db
from api.dependencies import get_current_user
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])


# ── Request / response schemas ────────────────────────────────────────────────

class _RegisterRequest(BaseModel):
    email:        EmailStr
    password:     str
    display_name: str | None = None


class _LoginRequest(BaseModel):
    email:    EmailStr
    password: str


class _RefreshRequest(BaseModel):
    refresh_token: str


class _AuthResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    user_id:       str
    email:         str
    role:          str
    display_name:  str | None


class _MeResponse(BaseModel):
    user_id:      str
    email:        str
    role:         str
    display_name: str | None
    is_active:    bool


# ── Helpers ───────────────────────────────────────────────────────────────────

def _build_response(user: UserRow) -> _AuthResponse:
    return _AuthResponse(
        access_token=_auth.create_access_token(user.id, user.role),
        refresh_token=_auth.create_refresh_token(user.id),
        user_id=user.id,
        email=user.email,
        role=user.role,
        display_name=user.display_name,
    )


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=_AuthResponse, status_code=201)
def register(body: _RegisterRequest, db: Session = Depends(get_db)):
    """Create a new learner account and return auth tokens."""
    if db.query(UserRow).filter(UserRow.email == body.email).first():
        raise HTTPException(status_code=409, detail="Email already registered.")
    user = UserRow(
        id=str(uuid.uuid4()),
        email=body.email,
        password_hash=_auth.hash_password(body.password),
        display_name=body.display_name,
        role="learner",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return _build_response(user)


@router.post("/login", response_model=_AuthResponse)
def login(body: _LoginRequest, db: Session = Depends(get_db)):
    """Authenticate with email + password. Returns access and refresh tokens."""
    user = db.query(UserRow).filter(UserRow.email == body.email).first()
    if not user or not _auth.verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password.")
    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated.")
    return _build_response(user)


@router.post("/refresh", response_model=_AuthResponse)
def refresh(body: _RefreshRequest, db: Session = Depends(get_db)):
    """Exchange a valid refresh token for a fresh pair of tokens."""
    try:
        payload = _auth.decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type.")
        user_id: str = payload.get("sub", "")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token.")
    user = db.get(UserRow, user_id)
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="User not found or deactivated.")
    return _build_response(user)


@router.get("/me", response_model=_MeResponse)
def me(current_user: UserRow = Depends(get_current_user)):
    """Return the profile of the currently authenticated user."""
    return _MeResponse(
        user_id=current_user.id,
        email=current_user.email,
        role=current_user.role,
        display_name=current_user.display_name,
        is_active=current_user.is_active,
    )
