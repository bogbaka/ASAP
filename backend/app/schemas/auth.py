from pydantic import BaseModel, Field


class OTPRequest(BaseModel):
    """Request a phone verification code."""

    phone_number: str = Field(
        min_length=8,
        max_length=20,
    )


class OTPVerificationRequest(BaseModel):
    """Submit a phone number and its verification code."""

    phone_number: str = Field(
        min_length=8,
        max_length=20,
    )

    code: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^[0-9]{6}$",
    )


class OTPResponse(BaseModel):
    """Response to a verification-code request."""

    message: str


class OTPVerificationResponse(BaseModel):
    """Response after checking a verification code."""

    verified: bool
    message: str
    access_token: str | None = None
    registration_token: str | None = None
