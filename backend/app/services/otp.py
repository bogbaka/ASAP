import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID

from app.core.config import settings


OTP_LENGTH = 6
OTP_EXPIRY_MINUTES = 5
MAX_OTP_ATTEMPTS = 5


def generate_otp() -> str:
    """Generate a cryptographically secure six-digit OTP."""
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(user_id: UUID, code: str) -> str:
    """Create a keyed hash bound to a specific user."""
    message = f"{user_id}:{code}".encode("utf-8")

    return hmac.new(
        settings.otp_hmac_secret.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


def verify_otp_hash(
    user_id: UUID,
    code: str,
    stored_hash: str,
) -> bool:
    """Compare an OTP with its stored hash securely."""
    expected_hash = hash_otp(user_id, code)

    return hmac.compare_digest(expected_hash, stored_hash)


def otp_expiration_time() -> datetime:
    """Return the time when a newly generated OTP expires."""
    return datetime.now(timezone.utc) + timedelta(
        minutes=OTP_EXPIRY_MINUTES
    )