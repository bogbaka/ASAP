from app.core.security import hash_password
from app.models import User


TEST_PHONE = "+2348098765432"
TEST_PASSWORD = "ASAP-test-password-123"


def create_test_user(
    test_database,
    *,
    phone_verified: bool = False,
    is_active: bool = True,
) -> None:
    """Create a test user with a securely hashed password."""

    with test_database() as db:
        user = User(
            phone_number=TEST_PHONE,
            display_name="Login Test User",
            password_hash=hash_password(TEST_PASSWORD),
            phone_verified=phone_verified,
            is_active=is_active,
        )

        db.add(user)
        db.commit()


def test_unverified_user_cannot_log_in(client, test_database):
    """An unverified user must verify their phone before logging in."""

    create_test_user(test_database, phone_verified=False)

    response = client.post(
        "/auth/login",
        json={
            "phone_number": TEST_PHONE,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == (
        "Please verify your phone number before logging in."
    )


def test_verified_user_can_log_in(client, test_database):
    """A verified user with correct credentials receives an access token."""

    create_test_user(test_database, phone_verified=True)

    response = client.post(
        "/auth/login",
        json={
            "phone_number": TEST_PHONE,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["access_token"]
    assert data["token_type"].lower() == "bearer"


def test_login_rejects_incorrect_password(client, test_database):
    """Incorrect credentials must not produce an access token."""

    create_test_user(test_database, phone_verified=True)

    response = client.post(
        "/auth/login",
        json={
            "phone_number": TEST_PHONE,
            "password": "Wrong-password-123",
        },
    )

    assert response.status_code == 401
    assert response.json()["detail"] == (
        "Invalid phone number or password."
    )


def test_inactive_user_cannot_log_in(client, test_database):
    """An inactive account must not receive an access token."""

    create_test_user(
        test_database,
        phone_verified=True,
        is_active=False,
    )

    response = client.post(
        "/auth/login",
        json={
            "phone_number": TEST_PHONE,
            "password": TEST_PASSWORD,
        },
    )

    assert response.status_code == 403
    assert response.json()["detail"] == "This account is inactive."