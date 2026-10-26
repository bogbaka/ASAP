from datetime import datetime, timedelta, timezone
from uuid import UUID

import jwt

from app.core.config import settings


ALGORITHM = "HS256"
REGISTRATION_TOKEN_EXPIRE_MINUTES = 10


def create_access_token(user_id: UUID) -> str:
    """Create a signed JWT for an authenticated user."""

    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user_id),
        "purpose": "access",
        "exp": now + timedelta(
            minutes=settings.access_token_expire_minutes
        ),
        "iat": now,
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=ALGORITHM,
    )


def decode_access_token(token: str) -> dict:
    """Validate an access token, rejecting registration tokens."""

    payload = jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[ALGORITHM],
        options={"require": ["sub", "exp", "iat"]},
    )

    # Allow previously issued access tokens without a purpose claim,
    # but never accept a registration token as an access token.
    if payload.get("purpose", "access") != "access":
        raise jwt.InvalidTokenError("Not an access token.")

    return payload


def create_registration_token(user_id: UUID) -> str:
    """Create a short-lived token for completing OTP registration."""

    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user_id),
        "purpose": "registration",
        "exp": now + timedelta(
            minutes=REGISTRATION_TOKEN_EXPIRE_MINUTES
        ),
        "iat": now,
    }

    return jwt.encode(
        payload,
        settings.jwt_secret_key,
        algorithm=ALGORITHM,
    )


def decode_registration_token(token: str) -> dict:
    """Validate a registration token."""

    payload = jwt.decode(
        token,
        settings.jwt_secret_key,
        algorithms=[ALGORITHM],
        options={
            "require": ["sub", "exp", "iat", "purpose"],
        },
    )

    if payload["purpose"] != "registration":
        raise jwt.InvalidTokenError("Not a registration token.")

    return payload