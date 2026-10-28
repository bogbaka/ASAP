"""Add support for passwordless phone registration.

Revision ID: a91c7e2f4d60
Revises: 14a081ca63bd
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a91c7e2f4d60"
down_revision: Union[str, None] = "14a081ca63bd"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Passwordless accounts do not require a password hash.
    op.alter_column(
        "users",
        "password_hash",
        existing_type=sa.String(length=255),
        nullable=True,
    )

    # OTP verification can happen before a user account exists.
    op.alter_column(
        "phone_verifications",
        "user_id",
        existing_type=sa.Uuid(),
        nullable=True,
    )

    # Store the phone number directly on each verification record.
    op.add_column(
        "phone_verifications",
        sa.Column("phone_number", sa.String(length=20), nullable=True),
    )

    # Preserve existing records by obtaining their phone numbers
    # from the users table.
    op.execute(
        sa.text(
            """
            UPDATE phone_verifications
            SET phone_number = (
                SELECT users.phone_number
                FROM users
                WHERE users.id = phone_verifications.user_id
            )
            WHERE phone_number IS NULL
            """
        )
    )

    # Do not silently proceed if any existing record could not
    # be associated with a phone number.
    connection = op.get_bind()
    unfilled_count = connection.execute(
        sa.text(
            """
            SELECT COUNT(*)
            FROM phone_verifications
            WHERE phone_number IS NULL
            """
        )
    ).scalar_one()

    if unfilled_count:
        raise RuntimeError(
            "Migration stopped: some phone verification records "
            "could not be associated with a phone number."
        )

    op.alter_column(
        "phone_verifications",
        "phone_number",
        existing_type=sa.String(length=20),
        nullable=False,
    )

    # Track successful OTP verification and completed registration.
    op.add_column(
        "phone_verifications",
        sa.Column(
            "verified_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.add_column(
        "phone_verifications",
        sa.Column(
            "registration_completed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    op.create_index(
        "ix_phone_verifications_phone_number",
        "phone_verifications",
        ["phone_number"],
        unique=False,
    )


def downgrade() -> None:
    # Refuse to discard data that the previous schema cannot represent.
    connection = op.get_bind()

    passwordless_count = connection.execute(
        sa.text("SELECT COUNT(*) FROM users WHERE password_hash IS NULL")
    ).scalar_one()

    unlinked_count = connection.execute(
        sa.text(
            "SELECT COUNT(*) FROM phone_verifications WHERE user_id IS NULL"
        )
    ).scalar_one()

    if passwordless_count or unlinked_count:
        raise RuntimeError(
            "Cannot safely downgrade: passwordless users or unlinked "
            "phone verification records exist. Resolve these records first."
        )

    op.drop_index(
        "ix_phone_verifications_phone_number",
        table_name="phone_verifications",
    )

    op.drop_column("phone_verifications", "registration_completed_at")
    op.drop_column("phone_verifications", "verified_at")
    op.drop_column("phone_verifications", "phone_number")

    op.alter_column(
        "phone_verifications",
        "user_id",
        existing_type=sa.Uuid(),
        nullable=False,
    )

    op.alter_column(
        "users",
        "password_hash",
        existing_type=sa.String(length=255),
        nullable=False,
    )
