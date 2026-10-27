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
    """Requesting an OTP returns a generic message without exposing the code."""

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


def test_verified_account_can_request_otp_for_login(
    client,
    test_database,
    monkeypatch,
):
    """A verified account can request an OTP for login."""

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
        user_id = user.id 

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
    assert len(sent_messages) == 1
    assert len(sent_messages[0]) == 6
    assert sent_messages[0].isdigit()

   
    # Confirm an OTP verification record was created.
    with test_database() as db:
        verification = db.scalar(
            select(PhoneVerification).where(
                PhoneVerification.user_id == user_id
            )
        )

        assert verification is not None
        assert verification.code_hash != sent_messages[0]


def test_correct_otp_verifies_account(
    client,
    test_database,
    monkeypatch,
):
    """A valid OTP should verify the phone and return an access token."""

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

    response_data = verify_response.json()

    assert response_data["verified"] is True
    assert (
        response_data["message"]
        == "Your phone number has been verified successfully."
    )

    # Existing users should receive an access token.
    assert response_data["access_token"]
    assert response_data["registration_token"] is None

    # Confirm the account and verification record were updated.
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

def test_new_user_can_complete_otp_registration(
    client,
        test_database,
        monkeypatch,
):
    """A new user can verify their phone and complete registration."""

    sent_messages = []

    def fake_send_verification_sms(phone_number, code):
        sent_messages.append(code)
        return True

    monkeypatch.setattr(
        "app.api.routes.auth.send_verification_sms",
        fake_send_verification_sms,
    )

    # Step 1: Request an OTP for a new phone number.
    request_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert request_response.status_code == 200
    assert len(sent_messages) == 1

    # Step 2: Verify the OTP.
    verify_response = client.post(
        "/auth/verify-otp",
        json={
            "phone_number": TEST_PHONE,
            "code": sent_messages[0],
        },
    )

    assert verify_response.status_code == 200

    verification_data = verify_response.json()

    assert verification_data["verified"] is True
    assert verification_data["registration_token"]
    assert verification_data["access_token"] is None

    # The new user should still be pending profile completion.
    with test_database() as db:
        user = db.scalar(
            select(User).where(
                User.phone_number == TEST_PHONE
            )
        )

        assert user is not None
        assert user.display_name == "Pending ASAP Profile"
        assert user.phone_verified is False

    # Step 3: Complete registration using the registration token.
    registration_response = client.post(
        "/auth/register",
        json={
            "registration_token": verification_data[
                "registration_token"
            ],
            "display_name": "New OTP User",
        },
    )

    assert registration_response.status_code == 201

    registration_data = registration_response.json()

    assert registration_data["access_token"]
    assert registration_data["token_type"].lower() == "bearer"
    assert registration_data["user"]["phone_number"] == TEST_PHONE
    assert registration_data["user"]["display_name"] == "New OTP User"

    # Step 4: Confirm that registration completed in the database.
    with test_database() as db:
        user = db.scalar(
            select(User).where(
                User.phone_number == TEST_PHONE
            )
        )

        assert user is not None
        assert user.display_name == "New OTP User"
        assert user.phone_verified is True
