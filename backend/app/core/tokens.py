from datetime import datetime, timedelta, timezone
from uuid import UUID

import jwt

from app.core.config import settings


ALGORITHM = "HS256"
REGISTRATION_TOKEN_EXPIRE_MINUTES = 10


def create_access_token(user_id: UUID) -> str:
    """Create a signed JWT access token for an authenticated user."""
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(
        minutes=settings.access_token_expire_minutes
    )

    payload = {
        "sub": str(user_id),
        "exp": expires_at,
        "iat": now,
        "purpose": "access",
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=ALGORITHM,
    )


def create_registration_token(phone_number: str) -> str:
    """Create a short-lived token for a verified, unregistered phone."""
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(
        minutes=REGISTRATION_TOKEN_EXPIRE_MINUTES
    )

    payload = {
        "sub": phone_number,
        "exp": expires_at,
        "iat": now,
        "purpose": "registration",
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=ALGORITHM,
    )


def decode_access_token(token: str) -> dict:
    """Decode and validate an access token."""
    payload = jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[ALGORITHM],
        options={"require": ["sub", "exp", "iat"]},
    )

    if payload.get("purpose", "access") != "access":
        raise jwt.InvalidTokenError("Not an access token.")

    return payload


def decode_registration_token(token: str) -> dict:
    """Decode and validate a phone-registration token."""
    payload = jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[ALGORITHM],
        options={"require": ["sub", "exp", "iat", "purpose"]},
    )

    if payload.get("purpose") != "registration":
        raise jwt.InvalidTokenError("Not a registration token.")

    return payload