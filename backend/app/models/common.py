from sqlalchemy import JSON, String, Text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.schema import MetaData

# PostgreSQL's historical 006-019 schema used JSONB and unbounded TEXT.  Keep
# those deployed types canonical while preserving portable JSON/String types
# for SQLite and other test dialects.
JsonType = JSON().with_variant(JSONB(), "postgresql")
PostgresTextType = String().with_variant(Text(), "postgresql")


# Standalone SQL 006-019 created these unbounded identifiers/status values as
# PostgreSQL TEXT.  Keeping the list explicit makes the cross-source contract
# reviewable and avoids a broad type-comparison exception in Alembic tests.
POSTGRES_TEXT_COLUMN_CONTRACT: dict[str, tuple[str, ...]] = {
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


def apply_postgres_type_contract(metadata: MetaData) -> None:
    """Apply the explicit SQL-legacy type contract to ORM metadata."""

    for table_name, column_names in POSTGRES_TEXT_COLUMN_CONTRACT.items():
        table = metadata.tables[table_name]
        for column_name in column_names:
            table.c[column_name].type = PostgresTextType
