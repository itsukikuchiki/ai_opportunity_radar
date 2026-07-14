"""legacy endpoint telemetry

Revision ID: 0005_legacy_endpoint_telemetry
Revises: 0004_reflection_version_registry
Create Date: 2026-07-05
"""
from alembic import op
import sqlalchemy as sa

revision = "0005_legacy_endpoint_telemetry"
down_revision = "0004_reflection_version_registry"
branch_labels = None
depends_on = None


def _table_names() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def _index_names(table_name: str) -> set[str]:
    return {
        index["name"]
        for index in sa.inspect(op.get_bind()).get_indexes(table_name)
        if index.get("name")
    }


def _create_index_if_missing(
    table_name: str,
    index_name: str,
    columns: list[str],
) -> None:
    if index_name not in _index_names(table_name):
        op.create_index(index_name, table_name, columns)


def upgrade() -> None:
    # SQL migration 018 may already have created this table.  Alembic is now
    # the sole migration authority, but it must be able to adopt that deployed
    # legacy shape without dropping its data.
    if "legacy_endpoint_telemetry" not in _table_names():
        op.create_table(
            "legacy_endpoint_telemetry",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("counter_name", sa.String(), nullable=False),
            sa.Column("endpoint", sa.String(), nullable=False),
            sa.Column("client_version", sa.String(), nullable=True),
            sa.Column("platform", sa.String(), nullable=True),
            sa.Column("user_id_hash", sa.String(), nullable=True),
            sa.Column("account_id_hash", sa.String(), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.func.now(),
            ),
        )
    _create_index_if_missing(
        "legacy_endpoint_telemetry",
        "idx_legacy_endpoint_counter",
        ["counter_name", "created_at"],
    )
    _create_index_if_missing(
        "legacy_endpoint_telemetry",
        "idx_legacy_endpoint_endpoint",
        ["endpoint", "created_at"],
    )
    _create_index_if_missing(
        "legacy_endpoint_telemetry",
        "idx_legacy_endpoint_user_hash",
        ["user_id_hash"],
    )
    _create_index_if_missing(
        "legacy_endpoint_telemetry",
        "idx_legacy_endpoint_account_hash",
        ["account_id_hash"],
    )


def downgrade() -> None:
    if "legacy_endpoint_telemetry" not in _table_names():
        return
    op.drop_index("idx_legacy_endpoint_account_hash", table_name="legacy_endpoint_telemetry")
    op.drop_index("idx_legacy_endpoint_user_hash", table_name="legacy_endpoint_telemetry")
    op.drop_index("idx_legacy_endpoint_endpoint", table_name="legacy_endpoint_telemetry")
    op.drop_index("idx_legacy_endpoint_counter", table_name="legacy_endpoint_telemetry")
    op.drop_table("legacy_endpoint_telemetry")
