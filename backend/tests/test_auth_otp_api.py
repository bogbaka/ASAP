from sqlalchemy import select

from app.models import PhoneVerification, User


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

    # The simulated SMS sender receives the code.
    assert len(sent_messages) == 1
    assert len(sent_messages[0]["code"]) == 6
    assert sent_messages[0]["code"].isdigit()

    # The HTTP response must never expose the OTP.
    assert sent_messages[0]["code"] not in response.text

    # Only the hashed OTP should be stored in the database.
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