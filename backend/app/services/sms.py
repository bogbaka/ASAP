from app.core.config import settings


def send_verification_sms(
    phone_number: str,
    code: str,
) -> bool:
    """Send a phone verification code through the configured SMS service."""

    if settings.app_env == "development":
        # Temporary development-only mock.
        # A real SMS provider will replace this implementation.
        print(
            f"Development SMS prepared for {phone_number}. "
            "OTP delivery is simulated."
        )
        return True

    # Production SMS delivery has not been configured yet.
    return False