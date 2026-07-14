"""candidate planning groups and plural candidates

Revision ID: 0006_candidate_planning
Revises: 0005_legacy_endpoint_telemetry
Create Date: 2026-07-12
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_candidate_planning"
down_revision = "0005_legacy_endpoint_telemetry"
branch_labels = None
depends_on = None


def _table_names() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


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


def _create_index_if_missing(
    table_name: str,
    index_name: str,
    columns: list[str],
) -> None:
    if index_name not in _index_names(table_name):
        op.create_index(index_name, table_name, columns)


def upgrade() -> None:
    tables = _table_names()

    if "candidate_groups" not in tables:
        op.create_table(
            "candidate_groups",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column(
                "user_id",
                sa.String(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("candidate_kind", sa.String(), nullable=False),
            sa.Column("period_start", sa.Date(), nullable=False),
            sa.Column("period_end", sa.Date(), nullable=False),
            sa.Column("source_hash", sa.String(), nullable=False),
            sa.Column("status", sa.String(), nullable=False, server_default="ready"),
            sa.Column(
                "required_signal_count", sa.Integer(), nullable=False, server_default="3"
            ),
            sa.Column(
                "eligible_signal_count", sa.Integer(), nullable=False, server_default="0"
            ),
            sa.Column("dirty", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("is_stale", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("stale_reason", sa.Text()),
            sa.Column("invalidated_at", sa.DateTime(timezone=True)),
            sa.Column("generation_started_at", sa.DateTime(timezone=True)),
            sa.Column("generation_finished_at", sa.DateTime(timezone=True)),
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
                "user_id",
                "candidate_kind",
                "period_start",
                "source_hash",
                name="uq_candidate_groups_source",
            ),
        )
    _create_index_if_missing(
        "candidate_groups",
        "idx_candidate_groups_read",
        ["user_id", "candidate_kind", "period_start", "status", "updated_at"],
    )

    tables = _table_names()
    if "micro_action_candidates" not in tables:
        op.create_table(
            "micro_action_candidates",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column("candidate_group_id", sa.String(), nullable=False),
            sa.Column(
                "user_id",
                sa.String(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("local_date", sa.Date(), nullable=False),
            sa.Column("rank", sa.Integer(), nullable=False),
            sa.Column("title", sa.String(), nullable=False),
            sa.Column("reason", sa.Text(), nullable=False, server_default=""),
            sa.Column("difficulty", sa.String(), nullable=False, server_default="very_light"),
            sa.Column("linked_signal_card_ids", sa.JSON(), nullable=False, server_default="[]"),
            sa.Column("focus_domain_ids", sa.JSON(), nullable=False, server_default="[]"),
            sa.Column("status", sa.String(), nullable=False, server_default="generated"),
            sa.Column("adopted_micro_action_id", sa.String()),
            sa.Column("source_hash", sa.String(), nullable=False),
            sa.Column("dirty", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("is_stale", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("stale_reason", sa.Text()),
            sa.Column("invalidated_at", sa.DateTime(timezone=True)),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.CheckConstraint(
                "rank BETWEEN 1 AND 3",
                name="ck_micro_action_candidates_rank",
            ),
        )
    _create_index_if_missing(
        "micro_action_candidates",
        "idx_micro_action_candidates_group",
        ["candidate_group_id", "rank"],
    )
    _create_index_if_missing(
        "micro_action_candidates",
        "idx_micro_action_candidates_read",
        ["user_id", "local_date", "status", "dirty", "is_stale", "rank"],
    )

    tables = _table_names()
    if "experiment_candidates" not in tables:
        op.create_table(
            "experiment_candidates",
            sa.Column("id", sa.String(), primary_key=True),
            sa.Column(
                "user_id",
                sa.String(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column("source_type", sa.String(), nullable=False),
            sa.Column("source_id", sa.String(), nullable=False),
            sa.Column("source_week_start", sa.Date(), nullable=False),
            sa.Column("source_week_end", sa.Date(), nullable=False),
            sa.Column("title", sa.String(), nullable=False),
            sa.Column("hypothesis", sa.Text(), nullable=False),
            sa.Column("suggested_action", sa.Text(), nullable=False),
            sa.Column("linked_signal_card_ids", sa.JSON(), nullable=False, server_default="[]"),
            sa.Column("linked_observation_ids", sa.JSON(), nullable=False, server_default="[]"),
            sa.Column("status", sa.String(), nullable=False, server_default="generated"),
            sa.Column("confidence_level", sa.String(), nullable=False, server_default="medium"),
            sa.Column("metadata_json", sa.JSON(), nullable=False, server_default="{}"),
            sa.Column("adopted_experiment_id", sa.String()),
            sa.Column("candidate_group_id", sa.String()),
            sa.Column("candidate_rank", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("source_hash", sa.String()),
            sa.Column("dirty", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("is_stale", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("stale_reason", sa.Text()),
            sa.Column("invalidated_at", sa.DateTime(timezone=True)),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        )
    else:
        columns = _column_names("experiment_candidates")
        additions = {
            # Some installations ran the SQL migrations before Alembic became
            # authoritative. Accept both the pre-017 and post-017 table shape.
            "dirty": sa.Column(
                "dirty", sa.Boolean(), nullable=False, server_default=sa.false()
            ),
            "is_stale": sa.Column(
                "is_stale", sa.Boolean(), nullable=False, server_default=sa.false()
            ),
            "stale_reason": sa.Column("stale_reason", sa.Text()),
            "invalidated_at": sa.Column(
                "invalidated_at", sa.DateTime(timezone=True)
            ),
            "candidate_group_id": sa.Column("candidate_group_id", sa.String()),
            "candidate_rank": sa.Column(
                "candidate_rank", sa.Integer(), nullable=False, server_default="1"
            ),
            "source_hash": sa.Column("source_hash", sa.String()),
        }
        for name, column in additions.items():
            if name not in columns:
                op.add_column("experiment_candidates", column)

    # If 0006 had to create the table, restore its established query indexes.
    # If the table already existed, keep those indexes and fill only gaps.
    experiment_indexes = {
        "idx_experiment_candidates_source": ["source_type", "source_id", "user_id"],
        "idx_experiment_candidates_week": ["user_id", "source_week_start", "status"],
        "idx_experiment_candidates_adopted": ["adopted_experiment_id"],
        "idx_experiment_candidates_stale": [
            "user_id",
            "source_week_start",
            "dirty",
            "is_stale",
            "status",
        ],
        "idx_experiment_candidates_group": [
            "candidate_group_id",
            "candidate_rank",
        ],
    }
    for index_name, index_columns in experiment_indexes.items():
        _create_index_if_missing(
            "experiment_candidates",
            index_name,
            index_columns,
        )


def downgrade() -> None:
    tables = _table_names()
    if "experiment_candidates" in tables:
        indexes = _index_names("experiment_candidates")
        if "idx_experiment_candidates_group" in indexes:
            op.drop_index(
                "idx_experiment_candidates_group",
                table_name="experiment_candidates",
            )
        columns = _column_names("experiment_candidates")
        with op.batch_alter_table("experiment_candidates") as batch:
            for name in ("source_hash", "candidate_rank", "candidate_group_id"):
                if name in columns:
                    batch.drop_column(name)
    if "micro_action_candidates" in tables:
        op.drop_table("micro_action_candidates")
    if "candidate_groups" in tables:
        op.drop_table("candidate_groups")
