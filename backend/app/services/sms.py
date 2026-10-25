from app.core.config import settings


def send_verification_sms(
    phone_number: str,
    code: str,
) -> bool:
    """
    Send a verification code.

    In development, print the code to the local server terminal.
    In production, fail until a real SMS provider is configured.
    """

    if settings.app_env == "development":
        masked_phone = (
            f"{phone_number[:3]}****{phone_number[-2:]}"
        )

        print(
            f"\n[ASAP DEVELOPMENT OTP] "
            f"Phone: {masked_phone} | Code: {code}\n"
        )

        return True

    return False