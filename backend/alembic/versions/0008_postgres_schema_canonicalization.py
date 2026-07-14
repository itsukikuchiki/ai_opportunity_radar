"""canonicalize PostgreSQL types, constraints, and index ordering

Revision ID: 0008_postgres_canonical
Revises: 0007_schema_reconcile
Create Date: 2026-07-14

Standalone SQL 006-019 historically used JSONB, unbounded TEXT, and several
descending indexes.  The first unified Alembic bridge reached equivalent data
semantics but could leave PostgreSQL physical schema drift on both fresh and
hybrid databases.  This revision makes that deployed contract exact.
"""

from __future__ import annotations

import re

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0008_postgres_canonical"
down_revision = "0007_schema_reconcile"
branch_labels = None
depends_on = None


JSONB_COLUMNS: tuple[tuple[str, str], ...] = (
    ("analytics_events", "properties_json"),
    ("backup_bundles", "payload"),
    ("backup_bundles", "counts_json"),
    ("desires", "related_pattern_ids"),
    ("desires", "related_friction_ids"),
    ("experiment_candidates", "linked_signal_card_ids"),
    ("experiment_candidates", "linked_observation_ids"),
    ("experiment_candidates", "metadata_json"),
    ("followup_questions", "options_json"),
    ("frictions", "related_pattern_ids"),
    ("frictions", "representative_quotes"),
    ("life_experiment_lifecycle_events", "payload"),
    ("life_experiment_rollups", "lineage"),
    ("micro_action_candidates", "linked_signal_card_ids"),
    ("micro_action_candidates", "focus_domain_ids"),
    ("model_usage_logs", "metadata_json"),
    ("opportunities", "related_pattern_ids"),
    ("opportunities", "related_friction_ids"),
    ("opportunities", "related_desire_ids"),
    ("patterns", "summary_json"),
    ("quota_gate_events", "metadata_json"),
    ("raw_memories", "metadata_json"),
    ("reflection_results", "content_json"),
    ("signal_cards", "raw_payload_json"),
    ("signal_cards", "linked_life_chain_stage"),
    ("signal_cards", "user_correction_json"),
    ("signal_cards", "token_usage_json"),
    ("signal_cards", "metadata_json"),
    ("trace_links", "metadata_json"),
    ("weekly_insights", "top_patterns_json"),
    ("weekly_insights", "top_frictions_json"),
    ("weekly_insights", "opportunity_snapshot_json"),
    ("weekly_insights", "chart_data_json"),
)


POSTGRES_TEXT_COLUMNS: dict[str, tuple[str, ...]] = {
    "candidate_groups": ("id", "user_id", "candidate_kind", "source_hash", "status"),
    "experiment_candidates": (
        "id", "user_id", "source_type", "source_id", "title", "status",
        "confidence_level", "adopted_experiment_id", "candidate_group_id",
        "source_hash",
    ),
    "legacy_endpoint_telemetry": (
        "id", "counter_name", "endpoint", "client_version", "platform",
        "user_id_hash", "account_id_hash",
    ),
    "life_experiment_lifecycle_events": (
        "id", "experiment_id", "user_id", "event_type", "source_type",
        "source_id", "status_from", "status_to",
    ),
    "life_experiment_rollups": (
        "experiment_id", "user_id", "root_experiment_id",
        "parent_experiment_id", "current_status", "title",
    ),
    "micro_action_candidates": (
        "id", "candidate_group_id", "user_id", "title", "difficulty",
        "status", "adopted_micro_action_id", "source_hash",
    ),
    "model_usage_logs": (
        "id", "user_id", "feature_key", "model_used", "parser_version",
        "prompt_version", "quota_decision", "source_event_id",
    ),
    "observation_signal_links": ("observation_id", "signal_id", "reason"),
    "observations": (
        "id", "user_id", "observation_type", "confidence", "status",
        "created_by", "source_ai_judgement_id", "suggested_pattern",
        "suggested_life_chain_stage",
    ),
    "pipeline_runs": (
        "id", "user_id", "pipeline_type", "source_type", "source_id",
        "status", "error_code", "pipeline_version",
    ),
    "quota_gate_events": (
        "id", "user_id", "feature_key", "entitlement", "period_type",
        "period_start", "decision", "source_event_id",
    ),
    "reflection_results": (
        "id", "user_id", "source_type", "source_id", "reflection_type",
        "ai_level", "status", "prompt_version", "model_version",
        "pipeline_version", "superseded_by",
    ),
    "signal_analysis_policy": ("signal_id", "privacy_level", "exclusion_reason"),
    "signal_cards": (
        "id", "user_id", "capture_id", "raw_memory_id", "source_type",
        "client_id", "server_id", "timezone", "language", "emotion",
        "scene", "friction", "positive_signal", "energy_load",
        "user_confirmation", "linked_experiment_id", "parser_version",
        "model_used", "prompt_version", "privacy_level", "migration_status",
        "deletion_reason",
    ),
    "signal_processing_state": (
        "signal_id", "sync_status", "assist_status", "reason_status",
        "daily_status", "weekly_status", "journey_status", "processing_version",
    ),
    "trace_links": (
        "id", "user_id", "source_type", "source_id", "target_type",
        "target_id", "relation_type", "status",
    ),
    "usage_counters": (
        "id", "user_id", "feature_key", "period_type", "period_start",
        "model_used", "source_event_id",
    ),
}


DESCENDING_INDEXES: dict[str, tuple[str, tuple[str, ...], str]] = {
    "idx_reflection_results_user_source": (
        "reflection_results",
        ("user_id", "source_type", "source_id", "reflection_type", "status"),
        "generated_at",
    ),
    "idx_reflection_results_user_source_state": (
        "reflection_results",
        ("user_id", "source_type", "source_id", "dirty", "is_stale"),
        "generated_at",
    ),
    "idx_pipeline_runs_user_source": (
        "pipeline_runs",
        ("user_id", "source_type", "source_id", "pipeline_type", "status"),
        "started_at",
    ),
    "idx_pipeline_runs_retry": (
        "pipeline_runs",
        ("status", "can_retry"),
        "updated_at",
    ),
    "idx_observations_user_status_date": (
        "observations",
        ("user_id", "status", "source_period_start"),
        "updated_at",
    ),
    "idx_life_experiment_events_exp": (
        "life_experiment_lifecycle_events",
        ("experiment_id",),
        "event_date",
    ),
    "idx_life_experiment_events_user_date": (
        "life_experiment_lifecycle_events",
        ("user_id",),
        "local_date",
    ),
    "idx_life_experiment_rollups_user_week": (
        "life_experiment_rollups",
        ("user_id",),
        "source_week_start",
    ),
    "idx_life_experiment_rollups_root": (
        "life_experiment_rollups",
        ("root_experiment_id",),
        "source_week_start",
    ),
    "idx_life_experiment_rollups_user_period": (
        "life_experiment_rollups",
        ("user_id", "source_week_start", "source_week_end"),
        "updated_at",
    ),
    "idx_trace_links_user_status": (
        "trace_links",
        ("user_id", "status"),
        "updated_at",
    ),
    "idx_candidate_groups_read": (
        "candidate_groups",
        ("user_id", "candidate_kind", "period_start", "status"),
        "updated_at",
    ),
}


def _columns(table_name: str) -> dict[str, dict[str, object]]:
    return {
        str(column["name"]): column
        for column in sa.inspect(op.get_bind()).get_columns(table_name)
    }


def _canonical_jsonb() -> None:
    for table_name, column_name in JSONB_COLUMNS:
        column = _columns(table_name)[column_name]
        existing_type = column["type"]
        if isinstance(existing_type, postgresql.JSONB):
            continue

        default = column.get("default")
        if default is not None:
            op.execute(
                sa.text(
                    f'ALTER TABLE "{table_name}" '
                    f'ALTER COLUMN "{column_name}" DROP DEFAULT'
                )
            )
        op.alter_column(
            table_name,
            column_name,
            existing_type=existing_type,
            type_=postgresql.JSONB(),
            postgresql_using=f'"{column_name}"::jsonb',
        )
        if default is not None:
            canonical_default = re.sub(
                r"::json\b",
                "::jsonb",
                str(default),
                flags=re.IGNORECASE,
            )
            op.execute(
                sa.text(
                    f'ALTER TABLE "{table_name}" '
                    f'ALTER COLUMN "{column_name}" '
                    f'SET DEFAULT {canonical_default}'
                )
            )


def _canonical_text() -> None:
    for table_name, column_names in POSTGRES_TEXT_COLUMNS.items():
        columns = _columns(table_name)
        for column_name in column_names:
            existing_type = columns[column_name]["type"]
            if isinstance(existing_type, postgresql.TEXT):
                continue
            op.alter_column(
                table_name,
                column_name,
                existing_type=existing_type,
                type_=sa.Text(),
                postgresql_using=f'"{column_name}"::text',
            )


def _canonical_named_constraints() -> None:
    inspector = sa.inspect(op.get_bind())
    unique_columns = ("user_id", "candidate_kind", "period_start", "source_hash")
    unique_constraints = inspector.get_unique_constraints("candidate_groups")
    matching_unique = next(
        (
            constraint
            for constraint in unique_constraints
            if tuple(constraint.get("column_names") or ()) == unique_columns
        ),
        None,
    )
    if matching_unique is None or matching_unique.get("name") != "uq_candidate_groups_source":
        if matching_unique is not None and matching_unique.get("name"):
            op.drop_constraint(
                str(matching_unique["name"]),
                "candidate_groups",
                type_="unique",
            )
        op.create_unique_constraint(
            "uq_candidate_groups_source",
            "candidate_groups",
            list(unique_columns),
        )

    checks = inspector.get_check_constraints("micro_action_candidates")
    canonical_check = next(
        (
            constraint
            for constraint in checks
            if constraint.get("name") == "ck_micro_action_candidates_rank"
        ),
        None,
    )
    rank_check = next(
        (
            constraint
            for constraint in checks
            if re.sub(
                r"[\s()]",
                "",
                str(constraint.get("sqltext", "")),
            ).lower()
            in {
                "rankbetween1and3",
                "rank>=1andrank<=3",
            }
        ),
        None,
    )
    if canonical_check is None:
        if rank_check is not None and rank_check.get("name"):
            op.drop_constraint(
                str(rank_check["name"]),
                "micro_action_candidates",
                type_="check",
            )
        op.create_check_constraint(
            "ck_micro_action_candidates_rank",
            "micro_action_candidates",
            "rank BETWEEN 1 AND 3",
        )


def _canonical_indexes() -> None:
    inspector = sa.inspect(op.get_bind())
    for index_name, (table_name, prefix, descending_column) in (
        DESCENDING_INDEXES.items()
    ):
        if index_name in {
            index.get("name") for index in inspector.get_indexes(table_name)
        }:
            op.drop_index(index_name, table_name=table_name)
        expressions: list[object] = [sa.column(name) for name in prefix]
        expressions.append(sa.column(descending_column).desc())
        op.create_index(index_name, table_name, expressions)

    # PostgreSQL's legacy identity index was explicitly partial.  Recreate it
    # even on a database that previously ran 0007's non-partial equivalent.
    signal_indexes = {
        index.get("name")
        for index in sa.inspect(op.get_bind()).get_indexes("signal_cards")
    }
    if "uq_signal_cards_user_client_id" in signal_indexes:
        op.drop_index(
            "uq_signal_cards_user_client_id",
            table_name="signal_cards",
        )
    op.create_index(
        "uq_signal_cards_user_client_id",
        "signal_cards",
        ["user_id", "client_id"],
        unique=True,
        postgresql_where=sa.text("client_id IS NOT NULL"),
    )


def upgrade() -> None:
    if op.get_bind().dialect.name != "postgresql":
        # Keep portable test schemas on the same index ordering.  JSONB/TEXT
        # and constraint-name reconciliation remain PostgreSQL-only.
        _canonical_indexes()
        return
    _canonical_jsonb()
    _canonical_text()
    _canonical_named_constraints()
    _canonical_indexes()


def downgrade() -> None:
    raise RuntimeError(
        "0008 PostgreSQL schema canonicalization is intentionally irreversible"
    )
