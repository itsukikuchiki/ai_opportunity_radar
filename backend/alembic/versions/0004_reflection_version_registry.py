"""reflection prompt model version registry

Revision ID: 0004_reflection_version_registry
Revises: 0003_signal_soft_delete
Create Date: 2026-07-05
"""
from alembic import op
import sqlalchemy as sa

revision = "0004_reflection_version_registry"
down_revision = "0003_signal_soft_delete"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "reflection_version_registry",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("source_type", sa.String(), nullable=False),
        sa.Column("reflection_type", sa.String(), nullable=False),
        sa.Column("ai_level", sa.String(), nullable=False),
        sa.Column("prompt_version", sa.String(), nullable=False),
        sa.Column("model_version", sa.String(), nullable=False),
        sa.Column("pipeline_version", sa.String(), nullable=False),
        sa.Column("rollout_reason", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "source_type",
            "reflection_type",
            "ai_level",
            name="uq_reflection_version_registry_key",
        ),
    )
    op.create_index(
        "ix_reflection_version_registry_source_type",
        "reflection_version_registry",
        ["source_type"],
    )
    op.create_index(
        "ix_reflection_version_registry_reflection_type",
        "reflection_version_registry",
        ["reflection_type"],
    )
    op.create_index(
        "ix_reflection_version_registry_ai_level",
        "reflection_version_registry",
        ["ai_level"],
    )


def downgrade() -> None:
    op.drop_index("ix_reflection_version_registry_ai_level", table_name="reflection_version_registry")
    op.drop_index("ix_reflection_version_registry_reflection_type", table_name="reflection_version_registry")
    op.drop_index("ix_reflection_version_registry_source_type", table_name="reflection_version_registry")
    op.drop_table("reflection_version_registry")
