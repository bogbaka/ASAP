from datetime import datetime, timedelta, timezone

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.core.security import verify_password
from app.core.tokens import (
    create_access_token,
    create_registration_token,
    decode_registration_token,
)
from app.db.dependencies import get_db
from app.models import PhoneVerification, User
from app.schemas.auth import (
    OTPRequest,
    OTPResponse,
    OTPVerificationRequest,
    OTPVerificationResponse,
)
from app.schemas.user import (
    RegistrationResponse,
    TokenResponse,
    UserCreate,
    UserLogin,
    UserResponse,
)
from app.services.otp import (
    MAX_OTP_ATTEMPTS,
    OTP_EXPIRY_MINUTES,
    generate_otp,
    hash_otp,
    otp_expiration_time,
    verify_otp_hash,
)
from app.services.sms import send_verification_sms

router = APIRouter(prefix="/auth", tags=["Authentication"])

OTP_RESEND_COOLDOWN_SECONDS = 60
OTP_RESEND_WINDOW_MINUTES = 15
MAX_OTP_RESENDS = 3


def _get_user_by_phone(
    db: Session,
    phone_number: str,
) -> User | None:
    """Find a user by phone number."""
    statement = (
        select(User)
        .where(User.phone_number == phone_number)
        .with_for_update()
    )
    return db.scalar(statement)


def _get_verification_by_phone(
    db: Session,
    phone_number: str,
) -> PhoneVerification | None:
    """Find the latest OTP record for a phone number."""
    statement = (
        select(PhoneVerification)
        .where(PhoneVerification.phone_number == phone_number)
        .order_by(PhoneVerification.created_at.desc())
        .with_for_update()
    )
    return db.scalars(statement).first()


def _issue_otp(
    db: Session,
    phone_number: str,
    verification: PhoneVerification | None,
    user: User | None,
    *,
    is_resend: bool = False,
) -> None:
    """Create and send an OTP while enforcing resend limits."""
    now = datetime.now(timezone.utc)

    if verification is None:
        verification = PhoneVerification(
            phone_number=phone_number,
            user_id=user.id if user else None,
            code_hash="pending",
            expires_at=otp_expiration_time(),
            attempts=0,
            resend_count=0,
            resend_window_started_at=now,
            last_sent_at=now,
        )
        db.add(verification)

    else:
        last_sent_at = verification.last_sent_at

        if verification.used_at is None and last_sent_at is not None:
            elapsed = (
                now - last_sent_at.replace(tzinfo=timezone.utc)
                if last_sent_at.tzinfo is None
                else now - last_sent_at
            )

            if elapsed.total_seconds() < OTP_RESEND_COOLDOWN_SECONDS:
                remaining = max(
                    1,
                    OTP_RESEND_COOLDOWN_SECONDS
                    - int(elapsed.total_seconds()),
                )
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=(
                        "Please wait before requesting another "
                        f"verification code. Try again in {remaining} seconds."
                    ),
                )

        if verification.used_at is not None and is_resend:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="This verification code can no longer be resent.",
            )

        window_started_at = verification.resend_window_started_at

        if window_started_at is None:
            verification.resend_window_started_at = now
            verification.resend_count = 0
        else:
            if window_started_at.tzinfo is None:
                window_started_at = window_started_at.replace(
                    tzinfo=timezone.utc
                )

            window_elapsed = now - window_started_at

            if window_elapsed >= timedelta(
                minutes=OTP_RESEND_WINDOW_MINUTES
            ):
                verification.resend_window_started_at = now
                verification.resend_count = 0

        if is_resend:
            if verification.resend_count >= MAX_OTP_RESENDS:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail=(
                        "You have reached the verification-code resend "
                        "limit. Please try again later."
                    ),
                )

            verification.resend_count += 1

        verification.phone_number = phone_number
        verification.user_id = user.id if user else None
        verification.attempts = 0
        verification.used_at = None
        verification.verified_at = None
        verification.registration_completed_at = None

        verification.last_sent_at = now
        verification.expires_at = otp_expiration_time()

    code = generate_otp()
    verification.code_hash = hash_otp(phone_number, code)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise

    try:
        sent = send_verification_sms(phone_number, code)
    except Exception:
        sent = False

    if not sent:
        verification.used_at = datetime.now(timezone.utc)

        try:
            db.commit()
        except Exception:
            db.rollback()

        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Unable to send the verification code. Please try again.",
        )


@router.post(
    "/request-otp",
    response_model=OTPResponse,
)
def request_otp(
    request: OTPRequest,
    db: Session = Depends(get_db),
) -> OTPResponse:
    """Request an OTP to register or sign in using a phone number."""
    phone_number = request.phone_number.strip()
    user = _get_user_by_phone(db, phone_number)

    # Keep the response generic to avoid revealing account information.
    if user is not None and not user.is_active:
        return OTPResponse(
            message=(
                "If this phone number can receive a verification code, "
                "a code will be sent."
            )
        )

    verification = _get_verification_by_phone(db, phone_number)

    _issue_otp(
        db=db,
        phone_number=phone_number,
        verification=verification,
        user=user,
    )

    return OTPResponse(
        message=(
            "If this phone number can receive a verification code, "
            "a code will be sent."
        )
    )


@router.post(
    "/resend-otp",
    response_model=OTPResponse,
)
def resend_otp(
    request: OTPRequest,
    db: Session = Depends(get_db),
) -> OTPResponse:
    """Resend an OTP subject to cooldown and rate limits."""
    phone_number = request.phone_number.strip()
    user = _get_user_by_phone(db, phone_number)

    if user is not None and not user.is_active:
        return OTPResponse(
            message=(
                "If this phone number can receive a verification code, "
                "a code will be sent."
            )
        )

    verification = _get_verification_by_phone(db, phone_number)

    if verification is None or verification.used_at is not None:
        return OTPResponse(
            message=(
                "If this phone number can receive a verification code, "
                "a code will be sent."
            )
        )

    _issue_otp(
        db=db,
        phone_number=phone_number,
        verification=verification,
        user=user,
        is_resend=True,
    )

    return OTPResponse(
        message=(
            "If this phone number can receive a verification code, "
            "a code will be sent."
        )
    )


@router.post(
    "/verify-otp",
    response_model=OTPVerificationResponse,
)
def verify_otp(
    request: OTPVerificationRequest,
    db: Session = Depends(get_db),
) -> OTPVerificationResponse:
    """Verify an OTP and issue the appropriate authentication token."""
    phone_number = request.phone_number.strip()

    verification = _get_verification_by_phone(db, phone_number)

    if verification is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code.",
        )

    if verification.used_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This verification code has already been used.",
        )

    now = datetime.now(timezone.utc)
    expires_at = verification.expires_at

    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)

    if now >= expires_at:
        verification.used_at = now
        db.commit()

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code.",
        )

    if verification.attempts >= MAX_OTP_ATTEMPTS:
        verification.used_at = now
        db.commit()

        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=(
                "Too many incorrect attempts. "
                "Please request a new verification code."
            ),
        )

    if not verify_otp_hash(
        phone_number,
        request.code,
        verification.code_hash,
    ):
        verification.attempts += 1

        if verification.attempts >= MAX_OTP_ATTEMPTS:
            verification.used_at = now

        db.commit()

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification code.",
        )

    user = _get_user_by_phone(db, phone_number)

    if user is not None and not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is inactive.",
        )

    verification.used_at = now
    verification.verified_at = now

    if user is not None:
        user.phone_verified = True

        db.commit()

        return OTPVerificationResponse(
            verified=True,
            message="Phone number verified successfully.",
            access_token=create_access_token(user.id),
        )

    db.commit()

    return OTPVerificationResponse(
        verified=True,
        message="Phone number verified. Continue creating your account.",
        registration_token=create_registration_token(phone_number),
    )


@router.post(
    "/register",
    response_model=RegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    user_data: UserCreate,
    db: Session = Depends(get_db),
) -> RegistrationResponse:
    """Create an account using a valid phone-verification token."""
    try:
        payload = decode_registration_token(user_data.registration_token)
    except (jwt.PyJWTError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired registration token.",
        )

    phone_number = payload.get("sub")

    if not isinstance(phone_number, str) or not phone_number:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid registration token.",
        )

    verification = _get_verification_by_phone(db, phone_number)

    if (
        verification is None
        or verification.verified_at is None
        or verification.used_at is None
        or verification.registration_completed_at is not None
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone verification is required before registration.",
        )

    if _get_user_by_phone(db, phone_number) is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this phone number already exists.",
        )

    display_name = user_data.display_name.strip()

    if len(display_name) < 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Display name must contain at least two characters.",
        )

    email = (
        user_data.email.strip().lower()
        if user_data.email is not None
        else None
    )

    if email == "":
        email = None

    if email is not None:
        existing_email = db.scalar(
            select(User).where(User.email == email)
        )

        if existing_email is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="An account with this email already exists.",
            )

    user = User(
        phone_number=phone_number,
        display_name=display_name,
        email=email,
        password_hash=None,
        phone_verified=True,
        is_active=True,
    )

    verification.registration_completed_at = datetime.now(timezone.utc)
    verification.user_id = user.id

    db.add(user)

    try:
        db.commit()
        db.refresh(user)
    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "An account with this phone number or email already exists."
            ),
        )

    return RegistrationResponse(
        user=user,
        access_token=create_access_token(user.id),
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    credentials: UserLogin,
    db: Session = Depends(get_db),
) -> TokenResponse:
    """Support legacy password-based accounts."""
    phone_number = credentials.phone_number.strip()
    user = db.scalar(
        select(User).where(User.phone_number == phone_number)
    )

    if (
        user is None
        or user.password_hash is None
        or not verify_password(
            credentials.password,
            user.password_hash,
        )
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

    return TokenResponse(
        access_token=create_access_token(user.id),
    )


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_my_profile(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """Return the profile of the authenticated user."""
    return current_user