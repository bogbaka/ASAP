
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


class UserCreate(BaseModel):
    """Create an account after verifying the phone number."""

    registration_token: str
    display_name: str = Field(min_length=2, max_length=80)
    email: str | None = Field(default=None, max_length=255)


class UserUpdate(BaseModel):
    """Fields a user may update on their own profile."""

    display_name: str | None = Field(default=None, min_length=2, max_length=80)
    email: str | None = Field(default=None, max_length=255)
    about: str | None = Field(default=None, max_length=139)

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, value: str | None) -> str | None:
        if value is not None:
            value = value.strip()
            if len(value) < 2:
                raise ValueError("Display name must contain at least two characters.")
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str | None) -> str | None:
        if value is not None:
            value = value.strip().lower()
            if not value:
                return None
        return value

    @field_validator("about")
    @classmethod
    def normalize_about(cls, value: str | None) -> str | None:
        if value is not None:
            value = value.strip()
            if not value:
                return None
        return value


class UserResponse(BaseModel):
    """Public user profile."""

    id: UUID
    phone_number: str
    display_name: str
    email: str | None
    about: str | None
    avatar_url: str | None

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
