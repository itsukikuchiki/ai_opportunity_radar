"""signal soft delete tombstones

Revision ID: 0003_signal_soft_delete
Revises: 0002_analytics
Create Date: 2026-07-05
"""
from alembic import op
import sqlalchemy as sa

revision = "0003_signal_soft_delete"
down_revision = "0002_analytics"
branch_labels = None
depends_on = None


def _table_exists(table_name: str) -> bool:
    return table_name in sa.inspect(op.get_bind()).get_table_names()


def _column_names(table_name: str) -> set[str]:
    return {
        column["name"]
        for column in sa.inspect(op.get_bind()).get_columns(table_name)
    }


def _index_names(table_name: str) -> set[str]:
    return {
        index["name"]
        for index in sa.inspect(op.get_bind()).get_indexes(table_name)
        if index.get("name")
    }


def upgrade() -> None:
    # `signal_cards` originally came from the standalone SQL 006 migration.
    # A database built only from Alembic therefore reaches this revision without
    # the table.  Leave creation of the complete table to the authoritative
    # reconciliation revision; on hybrid/legacy databases, add only the missing
    # tombstone fields.  This keeps both paths safe and idempotent.
    if not _table_exists("signal_cards"):
        return

    columns = _column_names("signal_cards")
    additions = {
        "deleted_at": sa.Column(
            "deleted_at", sa.DateTime(timezone=True), nullable=True
        ),
        "deletion_reason": sa.Column(
            "deletion_reason", sa.String(), nullable=True
        ),
        "tombstone_version": sa.Column(
            "tombstone_version",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        "restored_at": sa.Column(
            "restored_at", sa.DateTime(timezone=True), nullable=True
        ),
    }
    for name, column in additions.items():
        if name not in columns:
            op.add_column("signal_cards", column)

    if "ix_signal_cards_deleted_at" not in _index_names("signal_cards"):
        op.create_index(
            "ix_signal_cards_deleted_at", "signal_cards", ["deleted_at"]
        )


def downgrade() -> None:
    if not _table_exists("signal_cards"):
        return
    indexes = _index_names("signal_cards")
    if "ix_signal_cards_deleted_at" in indexes:
        op.drop_index("ix_signal_cards_deleted_at", table_name="signal_cards")
    columns = _column_names("signal_cards")
    with op.batch_alter_table("signal_cards") as batch:
        for name in (
            "restored_at",
            "tombstone_version",
            "deletion_reason",
            "deleted_at",
        ):
            if name in columns:
                batch.drop_column(name)
