from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.api.dependencies import get_current_user

from app.core.security import hash_password, verify_password
from app.core.tokens import create_access_token
from app.db.dependencies import get_db
from app.models import User
from app.schemas.user import (
    UserCreate,
    UserResponse,
    UserLogin,
    TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
)
def register_user(
    user_data: UserCreate,
    db: Session = Depends(get_db),
) -> UserResponse:
    """Register a new ASAP user."""
    existing_user = db.scalar(
        select(User).where(
            (User.phone_number == user_data.phone_number)
            | (
                (User.email == user_data.email)
                if user_data.email
                else False
            )
        )
    )

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number or email is already registered.",
        )

    user = User(
        phone_number=user_data.phone_number,
        display_name=user_data.display_name,
        email=user_data.email,
        password_hash=hash_password(user_data.password),
    )

    try:
        db.add(user)
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Phone number or email is already registered.",
        ) from None

    return user

@router.post("/login", response_model=TokenResponse)
def login_user(
    login_data: UserLogin,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """Authenticate a user and return an access token."""

    user = db.scalar(
        select(User).where(
            User.phone_number == login_data.phone_number
        )
    )

    if user is None or not verify_password(
        login_data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is inactive.",
        )

    access_token = create_access_token(user.id)

    return TokenResponse(access_token=access_token)
@router.get("/me", response_model=UserResponse)
def get_my_profile(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Return the profile of the authenticated user."""
    return current_user