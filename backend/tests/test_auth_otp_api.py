from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.api.routes.auth import (
    MAX_OTP_RESENDS,
    OTP_RESEND_COOLDOWN_SECONDS,
)
from app.models import PhoneVerification, User
from app.services.otp import MAX_OTP_ATTEMPTS


TEST_PHONE = "+2348098765432"


def create_unverified_user(test_database):
    """Create a test account without touching the real database."""

    with test_database() as db:
        user = User(
            phone_number=TEST_PHONE,
            display_name="OTP Test User",
            password_hash="test-password-hash",
            phone_verified=False,
            is_active=True,
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        return user.id


def test_request_otp_returns_generic_message(
    client,
    test_database,
    monkeypatch,
):
    """Requesting an OTP returns a generic message and never exposes the code."""

    create_unverified_user(test_database)
    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(
            {
                "phone_number": phone_number,
                "code": code,
            }
        )
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert response.status_code == 200
    assert response.json() == {
        "message": (
            "If the phone number belongs to an "
            "unverified account, a verification "
            "code will be sent."
        )
    }

    # The simulated SMS sender receives the OTP.
    assert len(sent_messages) == 1
    assert sent_messages[0]["phone_number"] == TEST_PHONE
    assert len(sent_messages[0]["code"]) == 6
    assert sent_messages[0]["code"].isdigit()

    # The HTTP response must never expose the OTP.
    assert sent_messages[0]["code"] not in response.text

    # Only the hashed OTP should be stored.
    with test_database() as db:
        verification = db.scalar(
            select(PhoneVerification)
        )

        assert verification is not None
        assert verification.code_hash != sent_messages[0]["code"]


def test_verified_account_does_not_receive_another_otp(
    client,
    test_database,
    monkeypatch,
):
    """A verified account should not receive another OTP."""

    with test_database() as db:
        user = User(
            phone_number=TEST_PHONE,
            display_name="Verified Test User",
            password_hash="test-password-hash",
            phone_verified=True,
            is_active=True,
        )

        db.add(user)
        db.commit()

    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert response.status_code == 200
    assert sent_messages == []

    with test_database() as db:
        verification = db.scalar(
            select(PhoneVerification)
        )

        assert verification is None


def test_correct_otp_verifies_account(
    client,
    test_database,
    monkeypatch,
):
    """A valid OTP should verify the user's phone number."""

    user_id = create_unverified_user(test_database)
    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    request_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert request_response.status_code == 200
    assert len(sent_messages) == 1

    # Obtain the OTP from the simulated SMS sender.
    code = sent_messages[0]

    verify_response = client.post(
        "/auth/verify-otp",
        json={
            "phone_number": TEST_PHONE,
            "code": code,
        },
    )

    assert verify_response.status_code == 200
    assert verify_response.json()["verified"] is True
    assert (
        verify_response.json()["message"]
        == "Your phone number has been verified successfully."
    )

    # Confirm the account was updated in the test database.
    with test_database() as db:
        user = db.get(User, user_id)

        verification = db.scalar(
            select(PhoneVerification).where(
                PhoneVerification.user_id == user_id
            )
        )

        assert user is not None
        assert user.phone_verified is True

        assert verification is not None
        assert verification.used_at is not None


def test_incorrect_otp_attempts_are_limited(
    client,
    test_database,
    monkeypatch,
):
    """Repeated incorrect codes should eventually be rate-limited."""

    create_unverified_user(test_database)
    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    request_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert request_response.status_code == 200
    assert len(sent_messages) == 1

    actual_code = sent_messages[0]

    # Guarantee that our test code differs from the actual OTP.
    wrong_code = "000000"

    if wrong_code == actual_code:
        wrong_code = "000001"

    for attempt in range(1, MAX_OTP_ATTEMPTS + 1):
        response = client.post(
            "/auth/verify-otp",
            json={
                "phone_number": TEST_PHONE,
                "code": wrong_code,
            },
        )

        if attempt < MAX_OTP_ATTEMPTS:
            assert response.status_code == 400
            assert response.json()["detail"] == (
                "Incorrect verification code."
            )
        else:
            assert response.status_code == 429
            assert response.json()["detail"] == (
                "Too many incorrect attempts. Request a new code."
            )

    # Confirm failed attempts were saved.
    with test_database() as db:
        user = db.scalar(
            select(User).where(
                User.phone_number == TEST_PHONE
            )
        )

        verification = db.scalar(
            select(PhoneVerification)
        )

        assert user is not None
        assert user.phone_verified is False

        assert verification is not None
        assert verification.attempts == MAX_OTP_ATTEMPTS


def test_resend_otp_obeys_cooldown(
    client,
    test_database,
    monkeypatch,
):
    """A second OTP request within 60 seconds should be rejected."""

    create_unverified_user(test_database)
    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    first_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert first_response.status_code == 200
    assert len(sent_messages) == 1

    second_response = client.post(
        "/auth/resend-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert second_response.status_code == 429
    assert "wait" in second_response.json()["detail"].lower()
    assert "Retry-After" in second_response.headers

    # The blocked request must not send another OTP.
    assert len(sent_messages) == 1


def test_resend_otp_enforces_resend_limit(
    client,
    test_database,
    monkeypatch,
):
    """No more than three resends should be allowed in the window."""

    create_unverified_user(test_database)
    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    first_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert first_response.status_code == 200
    assert len(sent_messages) == 1

    # Test three permitted resends and one additional blocked resend.
    for resend_number in range(1, MAX_OTP_RESENDS + 2):
        # Simulate elapsed cooldown without waiting 60 seconds.
        with test_database() as db:
            verification = db.scalar(
                select(PhoneVerification)
            )

            assert verification is not None

            verification.last_sent_at = (
                datetime.now(timezone.utc)
                - timedelta(
                    seconds=OTP_RESEND_COOLDOWN_SECONDS + 1
                )
            )

            db.commit()

        response = client.post(
            "/auth/resend-otp",
            json={"phone_number": TEST_PHONE},
        )

        if resend_number <= MAX_OTP_RESENDS:
            assert response.status_code == 200
        else:
            assert response.status_code == 429
            assert "resend limit" in (
                response.json()["detail"].lower()
            )

    # Initial request plus three permitted resends.
    assert len(sent_messages) == MAX_OTP_RESENDS + 1