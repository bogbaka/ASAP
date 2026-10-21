from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.core.security import hash_password, verify_password
from app.core.tokens import create_access_token
from app.db.dependencies import get_db
from app.models import PhoneVerification, User
from app.schemas.auth import (
    OTPRequest,
    OTPResponse,
    OTPVerificationRequest,
    OTPVerificationResponse,
)
from app.schemas.user import (
    TokenResponse,
    UserCreate,
    UserLogin,
    UserResponse,
)
from app.services.otp import (
    MAX_OTP_ATTEMPTS,
    generate_otp,
    hash_otp,
    otp_expiration_time,
    verify_otp_hash,
)
from app.services.sms import send_verification_sms


def _as_utc(value: datetime) -> datetime:
    """Normalize a datetime to timezone-aware UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)

    return value.astimezone(timezone.utc)


router = APIRouter(prefix="/auth", tags=["Authentication"])

OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_RESEND_WINDOW_MINUTES = 15
MAX_OTP_RESENDS = 3

GENERIC_OTP_MESSAGE = (
    "If the phone number belongs to an unverified account, "
    "a verification code will be sent."
)


def _get_user_by_phone(
    db: Session,
    phone_number: str,
) -> User | None:
    """Find and lock a user while changing verification state."""

    statement = (
        select(User)
        .where(User.phone_number == phone_number)
        .with_for_update()
    )

    return db.scalar(statement)


def _get_verification(
    db: Session,
    user_id,
) -> PhoneVerification | None:
    """Find the latest verification record and lock it."""

    statement = (
        select(PhoneVerification)
        .where(PhoneVerification.user_id == user_id)
        .order_by(PhoneVerification.created_at.desc())
        .with_for_update()
    )

    return db.scalars(statement).first()


def _issue_otp(
    db: Session,
    user: User,
    verification: PhoneVerification | None,
    *,
    is_resend: bool = False,
) -> None:
    """Issue an OTP while enforcing cooldown and resend limits."""

    now = datetime.now(timezone.utc)

    if verification is None:
        verification = PhoneVerification(
            user_id=user.id,
            code_hash="pending",
            expires_at=otp_expiration_time(),
            attempts=0,
            resend_count=0,
            resend_window_started_at=now,
            last_sent_at=now,
        )

        db.add(verification)

    else:
        if verification.used_at is not None and is_resend:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Request a new verification code first.",
            )

        # Enforce the cooldown between code requests.
        last_sent_at = _as_utc(verification.last_sent_at)

        seconds_since_last_send = (
            now - last_sent_at
        ).total_seconds()

        if seconds_since_last_send < OTP_RESEND_COOLDOWN_SECONDS:
            remaining = max(
                1,
                OTP_RESEND_COOLDOWN_SECONDS
                - int(seconds_since_last_send),
            )

            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=(
                    f"Please wait {remaining} seconds "
                    "before requesting another code."
                ),
                headers={"Retry-After": str(remaining)},
            )

        # Reset the resend counter after its 15-minute window.
        window_started_at = _as_utc(
            verification.resend_window_started_at
        )
        window_age = now - window_started_at

        if window_age >= timedelta(
            minutes=OTP_RESEND_WINDOW_MINUTES
        ):
            verification.resend_count = 0
            verification.resend_window_started_at = now

        if verification.resend_count >= MAX_OTP_RESENDS:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=(
                    "You have reached the resend limit. "
                    "Please try again after the 15-minute window."
                ),
            )

        # Count repeated requests against the same resend limit.
        verification.resend_count += 1
        verification.attempts = 0
        verification.used_at = None
        verification.last_sent_at = now

    code = generate_otp()

    verification.code_hash = hash_otp(user.id, code)
    verification.expires_at = otp_expiration_time()
    verification.attempts = 0
    verification.used_at = None
    verification.last_sent_at = now

    try:
        db.add(verification)
        db.commit()
        db.refresh(verification)

    except Exception:
        db.rollback()
        raise

    # Never return the OTP through the HTTP response.
    if not send_verification_sms(user.phone_number, code):
        # Invalidate the code while preserving resend history.
        verification.used_at = datetime.now(timezone.utc)

        try:
            db.commit()
        except Exception:
            db.rollback()

        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "Verification code delivery is unavailable. "
                "Please try again later."
            ),
        )


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

    conditions = [
        User.phone_number == user_data.phone_number
    ]

    if user_data.email:
        conditions.append(User.email == user_data.email)

    existing_user = db.scalar(
        select(User).where(or_(*conditions))
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


@router.post(
    "/request-otp",
    response_model=OTPResponse,
)
def request_otp(
    request: OTPRequest,
    db: Session = Depends(get_db),
) -> OTPResponse:
    """Request a phone verification code."""

    user = _get_user_by_phone(db, request.phone_number)

    if user is None or user.phone_verified:
        return OTPResponse(message=GENERIC_OTP_MESSAGE)

    verification = _get_verification(db, user.id)

    _issue_otp(
        db,
        user,
        verification,
        is_resend=False,
    )

    return OTPResponse(message=GENERIC_OTP_MESSAGE)


@router.post(
    "/resend-otp",
    response_model=OTPResponse,
)
def resend_otp(
    request: OTPRequest,
    db: Session = Depends(get_db),
) -> OTPResponse:
    """Resend an existing verification code within the limits."""

    user = _get_user_by_phone(db, request.phone_number)

    if user is None or user.phone_verified:
        return OTPResponse(message=GENERIC_OTP_MESSAGE)

    verification = _get_verification(db, user.id)

    if verification is None or verification.used_at is not None:
        return OTPResponse(message=GENERIC_OTP_MESSAGE)

    _issue_otp(
        db,
        user,
        verification,
        is_resend=True,
    )

    return OTPResponse(message=GENERIC_OTP_MESSAGE)


@router.post(
    "/verify-otp",
    response_model=OTPVerificationResponse,
)
def verify_otp(
    request: OTPVerificationRequest,
    db: Session = Depends(get_db),
) -> OTPVerificationResponse:
    """Verify a phone number using its six-digit code."""

    user = _get_user_by_phone(db, request.phone_number)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code.",
        )

    if user.phone_verified:
        return OTPVerificationResponse(
            verified=True,
            message="Your phone number is already verified.",
        )

    verification = _get_verification(db, user.id)

    if verification is None or verification.used_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code.",
        )

    now = datetime.now(timezone.utc)
    expires_at = _as_utc(verification.expires_at)

    if expires_at <= now:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "This verification code has expired. "
                "Request a new one."
            ),
        )

    if verification.attempts >= MAX_OTP_ATTEMPTS:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Too many incorrect attempts. Request a new code.",
        )

    valid_code = verify_otp_hash(
        user.id,
        request.code,
        verification.code_hash,
    )

    if not valid_code:
        verification.attempts += 1
        attempts_exhausted = (
            verification.attempts >= MAX_OTP_ATTEMPTS
        )

        # Save the attempt before returning an HTTP error.
        try:
            db.commit()
        except Exception:
            db.rollback()
            raise

        if attempts_exhausted:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many incorrect attempts. Request a new code.",
            )

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect verification code.",
        )

    user.phone_verified = True
    verification.used_at = now

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise

    return OTPVerificationResponse(
        verified=True,
        message="Your phone number has been verified successfully.",
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
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

    # Reject invalid credentials.
    if user is None or not verify_password(
        login_data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid phone number or password.",
        )

    # Reject inactive accounts.
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is inactive.",
        )

    # Require phone verification before login.
    if not user.phone_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please verify your phone number before logging in.",
        )

    # Issue a token only after all checks pass.
    access_token = create_access_token(user.id)

    return TokenResponse(access_token=access_token)


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_my_profile(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Return the profile of the authenticated user."""

    return current_user