"""
api/auth.py -- Password hashing and JWT utilities.
"""

from __future__ import annotations

import time
from typing import Any

import bcrypt
from jose import jwt

from api.config import settings

_7_DAYS = 7 * 24 * 3600


def hash_password(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode(), hashed.encode())


def create_access_token(sub: str, role: str) -> str:
    expire = int(time.time()) + settings.access_token_expire_minutes * 60
    return jwt.encode(
        {"sub": sub, "role": role, "exp": expire, "type": "access"},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def create_refresh_token(sub: str) -> str:
    expire = int(time.time()) + _7_DAYS
    return jwt.encode(
        {"sub": sub, "exp": expire, "type": "refresh"},
        settings.jwt_secret_key,
        algorithm=settings.jwt_algorithm,
    )


def decode_token(token: str) -> dict[str, Any]:
    return jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[settings.jwt_algorithm],
    )
