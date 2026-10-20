from pydantic import BaseModel, Field


class OTPRequest(BaseModel):
    """Request a verification code for a phone number."""

    phone_number: str = Field(min_length=8, max_length=20)


class OTPVerificationRequest(BaseModel):
    """Submit a phone number and its verification code."""

    phone_number: str = Field(min_length=8, max_length=20)
    code: str = Field(
        min_length=6,
        max_length=6,
        pattern=r"^[0-9]{6}$",
    )


class OTPResponse(BaseModel):
    """Response to a verification-code request."""

    message: str


class OTPVerificationResponse(BaseModel):
    """Response after successful OTP verification."""

    verified: bool
    message: str
    registration_token: str | None = None
    access_token: str | None = None
    token_type: str = "bearer"