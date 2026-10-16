from uuid import UUID

from pydantic import BaseModel, Field


class UserCreate(BaseModel):
    phone_number: str = Field(min_length=8, max_length=20)
    display_name: str = Field(min_length=2, max_length=80)
    password: str = Field(min_length=8, max_length=128)
    email: str | None = None


class UserResponse(BaseModel):
    id: UUID
    phone_number: str
    display_name: str
    email: str | None

    model_config = {"from_attributes": True}