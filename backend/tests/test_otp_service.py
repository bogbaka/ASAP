from datetime import datetime, timedelta, timezone
from uuid import uuid4

from app.services.otp import (
    MAX_OTP_ATTEMPTS,
    OTP_EXPIRY_MINUTES,
    generate_otp,
    hash_otp,
    otp_expiration_time,
    verify_otp_hash,
)


def test_generated_otp_contains_six_digits():
    """Generated OTPs should contain exactly six digits."""

    code = generate_otp()

    assert len(code) == 6
    assert code.isdigit()


def test_generated_otp_preserves_leading_zeroes():
    """The OTP generator should return a string."""

    code = generate_otp()

    assert isinstance(code, str)
    assert len(code) == 6


def test_otp_hash_is_consistent():
    """The same user and code should produce the same hash."""

    user_id = uuid4()
    code = "123456"

    first_hash = hash_otp(user_id, code)
    second_hash = hash_otp(user_id, code)

    assert first_hash == second_hash


def test_otp_hash_changes_for_different_codes():
    """Different codes should produce different hashes."""

    user_id = uuid4()

    first_hash = hash_otp(user_id, "123456")
    second_hash = hash_otp(user_id, "654321")

    assert first_hash != second_hash


def test_otp_hash_is_bound_to_user():
    """A code hash for one user should not validate for another."""

    first_user = uuid4()
    second_user = uuid4()
    code = "123456"

    stored_hash = hash_otp(first_user, code)

    assert verify_otp_hash(
        first_user,
        code,
        stored_hash,
    )

    assert not verify_otp_hash(
        second_user,
        code,
        stored_hash,
    )


def test_wrong_otp_does_not_validate():
    """An incorrect code should fail verification."""

    user_id = uuid4()
    stored_hash = hash_otp(user_id, "123456")

    assert not verify_otp_hash(
        user_id,
        "654321",
        stored_hash,
    )


def test_otp_expiration_is_five_minutes():
    """A newly generated OTP should expire after five minutes."""

    before = datetime.now(timezone.utc)
    expires_at = otp_expiration_time()
    after = datetime.now(timezone.utc)

    earliest_expected = before + timedelta(
        minutes=OTP_EXPIRY_MINUTES
    )
    latest_expected = after + timedelta(
        minutes=OTP_EXPIRY_MINUTES
    )

    assert earliest_expected <= expires_at <= latest_expected


def test_otp_security_limits_are_configured():
    """The OTP service should use the expected security limits."""

    assert OTP_EXPIRY_MINUTES == 5
    assert MAX_OTP_ATTEMPTS == 5