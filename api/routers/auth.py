"""
api/routers/auth.py -- JWT authentication endpoints.

POST /api/v1/auth/register  -- create new learner account
POST /api/v1/auth/login     -- exchange email+password for tokens
POST /api/v1/auth/refresh   -- exchange refresh token for new access token
GET  /api/v1/auth/me        -- return current user profile
"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field

from api.auth import (
    create_access_token,
    create_password_reset_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from api.config import settings
from api.db import SessionLocal
from api.dependencies import get_current_user
from api.models.users import UserRow

router = APIRouter(prefix="/api/v1/auth", tags=["Auth"])


class _LoginRequest(BaseModel):
    email: EmailStr
    password: str


class _RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)
    display_name: Optional[str] = None


class _RefreshRequest(BaseModel):
    refresh_token: str


class _AuthResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    user_id:       str
    email:         str
    role:          str
    display_name:  Optional[str]


class _MeResponse(BaseModel):
    user_id:      str
    email:        str
    role:         str
    display_name: Optional[str]
    is_active:    bool


@router.post("/register", response_model=_AuthResponse, status_code=201)
def register(body: _RegisterRequest):
    from api.email_service import send_welcome_email

    with SessionLocal() as db:
        existing = db.query(UserRow).filter(UserRow.email == body.email).first()
        if existing:
            raise HTTPException(status_code=409, detail="Email already registered.")
        user = UserRow(
            email=body.email,
            password_hash=hash_password(body.password),
            role="learner",
            display_name=body.display_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        out = _AuthResponse(
            access_token=create_access_token(user.id, user.role),
            refresh_token=create_refresh_token(user.id),
            user_id=user.id,
            email=user.email,
            role=user.role,
            display_name=user.display_name,
        )

    # Fire-and-forget — email errors never block registration
    send_welcome_email(out.email, out.display_name or "")
    return out


@router.post("/login", response_model=_AuthResponse)
def login(body: _LoginRequest):
    _401 = HTTPException(status_code=401, detail="Invalid email or password.")
    with SessionLocal() as db:
        user = db.query(UserRow).filter(UserRow.email == body.email).first()
        if user is None or not user.is_active:
            raise _401
        if not verify_password(body.password, user.password_hash):
            raise _401
        return _AuthResponse(
            access_token=create_access_token(user.id, user.role),
            refresh_token=create_refresh_token(user.id),
            user_id=user.id,
            email=user.email,
            role=user.role,
            display_name=user.display_name,
        )


@router.post("/refresh", response_model=_AuthResponse)
def refresh(body: _RefreshRequest):
    from jose import JWTError
    _401 = HTTPException(status_code=401, detail="Invalid or expired refresh token.")
    try:
        payload = decode_token(body.refresh_token)
        if payload.get("type") != "refresh":
            raise _401
        user_id: str = payload.get("sub", "")
        if not user_id:
            raise _401
    except JWTError:
        raise _401
    with SessionLocal() as db:
        user = db.get(UserRow, user_id)
    if user is None or not user.is_active:
        raise _401
    return _AuthResponse(
        access_token=create_access_token(user.id, user.role),
        refresh_token=create_refresh_token(user.id),
        user_id=user.id,
        email=user.email,
        role=user.role,
        display_name=user.display_name,
    )


@router.get("/me", response_model=_MeResponse)
def me(current_user: UserRow = Depends(get_current_user)):
    return _MeResponse(
        user_id=current_user.id,
        email=current_user.email,
        role=current_user.role,
        display_name=current_user.display_name,
        is_active=current_user.is_active,
    )


class _ChangePasswordRequest(BaseModel):
    current_password: str
    new_password:     str = Field(min_length=8)


@router.post("/change-password", status_code=204)
def change_password(
    body: _ChangePasswordRequest,
    current_user: UserRow = Depends(get_current_user),
):
    """Allow an authenticated user to change their own password."""
    if not verify_password(body.current_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect.")
    with SessionLocal() as db:
        user = db.get(UserRow, current_user.id)
        user.password_hash = hash_password(body.new_password)
        db.commit()


class _ForgotPasswordRequest(BaseModel):
    email: EmailStr


class _ResetPasswordRequest(BaseModel):
    token:        str
    new_password: str = Field(min_length=8)


@router.post("/forgot-password", status_code=204)
def forgot_password(body: _ForgotPasswordRequest):
    """
    Send a password-reset link to the given email address.
    Always returns 204 regardless of whether the address exists
    (prevents email enumeration attacks).
    """
    from api.email_service import send_password_reset_email, is_configured

    if not is_configured():
        return  # silently no-op when email not wired up

    with SessionLocal() as db:
        user = db.query(UserRow).filter(UserRow.email == body.email).first()

    if user is None:
        return  # don't reveal that the address is unknown

    token = create_password_reset_token(user.id)
    reset_link = f"{settings.app_base_url}/reset-password?token={token}"
    send_password_reset_email(to=user.email, reset_link=reset_link)


@router.post("/reset-password", status_code=204)
def reset_password(body: _ResetPasswordRequest):
    """Consume a password-reset JWT and set a new password."""
    from jose import JWTError

    _400 = HTTPException(status_code=400, detail="Invalid or expired reset link.")
    try:
        payload = decode_token(body.token)
        if payload.get("type") != "password_reset":
            raise _400
        user_id: str = payload.get("sub", "")
        if not user_id:
            raise _400
    except JWTError:
        raise _400

    with SessionLocal() as db:
        user = db.get(UserRow, user_id)
        if user is None:
            raise _400
        user.password_hash = hash_password(body.new_password)
        db.commit()
