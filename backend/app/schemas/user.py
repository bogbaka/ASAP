from uuid import UUID

from pydantic import BaseModel, Field


class UserCreate(BaseModel):
    """Create an account after verifying the phone number."""

    registration_token: str
    display_name: str = Field(min_length=2, max_length=80)
    email: str | None = Field(default=None, max_length=255)


class UserResponse(BaseModel):
    """Public user profile."""

    id: UUID
    phone_number: str
    display_name: str
    email: str | None

    model_config = {"from_attributes": True}


class UserLogin(BaseModel):
    """Legacy password-based login for existing accounts."""

    phone_number: str = Field(min_length=8, max_length=20)
    password: str


class TokenResponse(BaseModel):
    """Authentication access token."""

    access_token: str
    token_type: str = "bearer"


class RegistrationResponse(BaseModel):
    """Newly created account and its access token."""

    user: UserResponse
    access_token: str
    token_type: str = "bearer"