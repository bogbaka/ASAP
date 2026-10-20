from sqlalchemy import select

from app.models import PhoneVerification, User


TEST_PHONE = "+2348098765432"

GENERIC_OTP_MESSAGE = {
    "message": (
        "If this phone number can receive a verification code, "
        "a code will be sent."
    )
}


def create_unverified_user(test_database):
    """Create an existing account that has not verified its phone."""
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
    """Requesting an OTP returns a generic message and stores a hash."""
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
    assert response.json() == GENERIC_OTP_MESSAGE

    assert len(sent_messages) == 1
    assert sent_messages[0]["phone_number"] == TEST_PHONE
    assert len(sent_messages[0]["code"]) == 6
    assert sent_messages[0]["code"].isdigit()
    assert sent_messages[0]["code"] not in response.text

    with test_database() as db:
        verification = db.scalar(select(PhoneVerification))

        assert verification is not None
        assert verification.phone_number == TEST_PHONE
        assert verification.code_hash != sent_messages[0]["code"]


def test_verified_account_can_request_otp_to_sign_in(
    client,
    test_database,
    monkeypatch,
):
    """An existing verified user can request an OTP to sign in."""
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
    assert response.json() == GENERIC_OTP_MESSAGE

    assert len(sent_messages) == 1
    assert sent_messages[0]["phone_number"] == TEST_PHONE
    assert len(sent_messages[0]["code"]) == 6
    assert sent_messages[0]["code"].isdigit()

    with test_database() as db:
        verification = db.scalar(select(PhoneVerification))

        assert verification is not None
        assert verification.phone_number == TEST_PHONE
        assert verification.code_hash != sent_messages[0]["code"]