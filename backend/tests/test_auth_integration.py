from sqlalchemy import select

from app.models import PhoneVerification, User


TEST_PHONE = "+2348012345678"
TEST_PASSWORD = "ASAP-integration-test-123"


def test_complete_authentication_flow(
    client,
    test_database,
    monkeypatch,
):
    """Test registration through authenticated profile access."""

    sent_messages = []

    # Simulate SMS delivery without contacting a real SMS provider.
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

    # STEP 1: Register a new account.
    register_response = client.post(
        "/auth/register",
        json={
            "phone_number": TEST_PHONE,
            "display_name": "ASAP Integration User",
            "password": TEST_PASSWORD,
        },
    )

    assert register_response.status_code == 201
    assert register_response.json()["phone_number"] == TEST_PHONE

    # STEP 2: Login must fail before phone verification.
    login_data = {
        "phone_number": TEST_PHONE,
        "password": TEST_PASSWORD,
    }

    early_login_response = client.post(
        "/auth/login",
        json=login_data,
    )

    assert early_login_response.status_code == 403
    assert early_login_response.json()["detail"] == (
        "Please verify your phone number before logging in."
    )

    # STEP 3: Request a verification code.
    otp_response = client.post(
        "/auth/request-otp",
        json={"phone_number": TEST_PHONE},
    )

    assert otp_response.status_code == 200
    assert len(sent_messages) == 1

    # Obtain the code from our simulated SMS sender.
    verification_code = sent_messages[0]["code"]

    assert sent_messages[0]["phone_number"] == TEST_PHONE
    assert len(verification_code) == 6
    assert verification_code.isdigit()

    # The OTP must never appear in the HTTP response.
    assert verification_code not in otp_response.text

    # STEP 4: Verify the phone number.
    verify_response = client.post(
        "/auth/verify-otp",
        json={
            "phone_number": TEST_PHONE,
            "code": verification_code,
        },
    )

    assert verify_response.status_code == 200
    assert verify_response.json()["verified"] is True

    # Confirm that verification was persisted.
    with test_database() as db:
        user = db.scalar(
            select(User).where(User.phone_number == TEST_PHONE)
        )

        assert user is not None
        assert user.phone_verified is True

        verification = db.scalar(
            select(PhoneVerification).where(
                PhoneVerification.user_id == user.id
            )
        )

        assert verification is not None
        assert verification.used_at is not None

    # STEP 5: Login after successful verification.
    login_response = client.post(
        "/auth/login",
        json=login_data,
    )

    assert login_response.status_code == 200

    token_data = login_response.json()

    assert token_data["access_token"]
    assert token_data["token_type"].lower() == "bearer"

    # STEP 6: Access the authenticated user's profile.
    profile_response = client.get(
        "/auth/me",
        headers={
            "Authorization": (
                f"Bearer {token_data['access_token']}"
            )
        },
    )

    assert profile_response.status_code == 200

    profile = profile_response.json()

    assert profile["phone_number"] == TEST_PHONE
    assert profile["display_name"] == "ASAP Integration User"