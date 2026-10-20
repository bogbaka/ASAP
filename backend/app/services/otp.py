import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from app.core.config import settings


OTP_LENGTH = 6
OTP_EXPIRY_MINUTES = 5
MAX_OTP_ATTEMPTS = 5


def generate_otp() -> str:
    """Generate a cryptographically secure six-digit OTP."""
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_otp(phone_number: str, code: str) -> str:
    """Create a keyed hash bound to a phone number."""
    message = f"{phone_number}:{code}".encode("utf-8")

    return hmac.new(
        settings.otp_hmac_secret.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()


def verify_otp_hash(
    phone_number: str,
    code: str,
    stored_hash: str,
) -> bool:
    """Compare an OTP with its stored hash securely."""
    expected_hash = hash_otp(phone_number, code)

    return hmac.compare_digest(expected_hash, stored_hash)


def otp_expiration_time() -> datetime:
    """Return the expiration time for a newly generated OTP."""
    return datetime.now(timezone.utc) + timedelta(
        minutes=OTP_EXPIRY_MINUTES
    )