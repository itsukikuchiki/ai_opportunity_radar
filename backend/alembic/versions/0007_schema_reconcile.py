"""authoritative schema reconciliation

Revision ID: 0007_schema_reconcile
Revises: 0006_candidate_planning
Create Date: 2026-07-14 08:20:13.143586
"""
import json

from alembic import op
import sqlalchemy as sa


revision = "0007_schema_reconcile"
down_revision = '0006_candidate_planning'
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


def _create_table_if_missing(
    table_name: str,
    *columns_and_constraints: object,
    **kwargs: object,
) -> None:
    if table_name in _table_names():
        return
    op.create_table(table_name, *columns_and_constraints, **kwargs)


def _create_index_if_missing(
    index_name: str,
    table_name: str,
    columns: list[str],
    **kwargs: object,
) -> None:
    if table_name not in _table_names():
        raise RuntimeError(
            f"cannot create index {index_name}: table {table_name} is missing"
        )
    if str(index_name) in _index_names(table_name):
        return
    op.create_index(index_name, table_name, columns, **kwargs)


def _drop_index_if_exists(table_name: str, index_name: str) -> None:
    if index_name in _index_names(table_name):
        op.drop_index(index_name, table_name=table_name)


def _add_column_if_missing(table_name: str, column: sa.Column) -> None:
    if table_name not in _table_names():
        raise RuntimeError(
            f"cannot add column {column.name}: table {table_name} is missing"
        )
    if column.name not in _column_names(table_name):
        op.add_column(table_name, column)


def _ensure_unique_index(
    table_name: str,
    index_name: str,
    columns: list[str],
) -> None:
    expected = tuple(columns)
    # Some local databases were created directly from the former ORM contract
    # and already have an equivalent UNIQUE constraint. Preserve it: it has the
    # same cross-database NULL and deduplication semantics.
    if any(
        tuple(constraint.get("column_names") or ()) == expected
        for constraint in sa.inspect(op.get_bind()).get_unique_constraints(
            table_name
        )
    ):
        return

    existing = next(
        (
            index
            for index in sa.inspect(op.get_bind()).get_indexes(table_name)
            if index.get("name") == index_name
        ),
        None,
    )
    if existing is not None:
        dialect_options = existing.get("dialect_options") or {}
        is_partial = any(
            key.endswith("_where") and value is not None
            for key, value in dialect_options.items()
        )
        if (
            bool(existing.get("unique"))
            and tuple(existing.get("column_names") or ()) == expected
            and not is_partial
        ):
            return
        op.drop_index(index_name, table_name=table_name)
    op.create_index(index_name, table_name, columns, unique=True)


def _deduplicate_usage_counters() -> None:
    """Merge historical duplicate period counters before adding uniqueness."""

    bind = op.get_bind()
    table = sa.Table("usage_counters", sa.MetaData(), autoload_with=bind)
    keys = (
        table.c.user_id,
        table.c.feature_key,
        table.c.period_type,
        table.c.period_start,
    )
    duplicate_groups = bind.execute(
        sa.select(*keys).group_by(*keys).having(sa.func.count() > 1)
    ).all()
    for group in duplicate_groups:
        predicate = sa.and_(
            *(column == value for column, value in zip(keys, group, strict=True))
        )
        rows = bind.execute(
            sa.select(table).where(predicate).order_by(table.c.created_at, table.c.id)
        ).mappings().all()
        keeper = rows[-1]
        bind.execute(
            table.update()
            .where(table.c.id == keeper["id"])
            .values(
                count=sum(int(row["count"] or 0) for row in rows),
                token_input=sum(int(row["token_input"] or 0) for row in rows),
                token_output=sum(int(row["token_output"] or 0) for row in rows),
                token_cached_input=sum(
                    int(row["token_cached_input"] or 0) for row in rows
                ),
            )
        )
        bind.execute(
            table.delete().where(
                table.c.id.in_([row["id"] for row in rows[:-1]])
            )
        )


def _ensure_not_nullable(table_name: str, column_name: str) -> None:
    inspected = next(
        column
        for column in sa.inspect(op.get_bind()).get_columns(table_name)
        if column["name"] == column_name
    )
    if not inspected.get("nullable", True):
        return
    op.execute(
        sa.text(
            f'UPDATE "{table_name}" '
            f'SET "{column_name}" = CURRENT_TIMESTAMP '
            f'WHERE "{column_name}" IS NULL'
        )
    )
    with op.batch_alter_table(table_name) as batch:
        batch.alter_column(
            column_name,
            existing_type=inspected["type"],
            nullable=False,
        )


def _backfill_signal_state_and_policy() -> None:
    bind = op.get_bind()
    metadata = sa.MetaData()
    signals = sa.Table("signal_cards", metadata, autoload_with=bind)
    states = sa.Table("signal_processing_state", metadata, autoload_with=bind)
    policies = sa.Table("signal_analysis_policy", metadata, autoload_with=bind)

    signal_rows = bind.execute(
        sa.select(
            signals.c.id,
            signals.c.included_in_summary,
            signals.c.included_in_weekly,
            signals.c.included_in_journey,
            signals.c.privacy_level,
            signals.c.user_confirmation,
            signals.c.deleted_at,
        )
    ).mappings()
    for row in signal_rows:
        signal_id = row["id"]
        privacy_level = row["privacy_level"] or "private"
        confirmation = row["user_confirmation"] or "unconfirmed"
        inaccurate = confirmation == "inaccurate"
        is_deleted = row["deleted_at"] is not None
        is_analysis_excluded = (
            is_deleted
            or inaccurate
            or privacy_level in {"sensitive", "excluded", "do_not_analyze"}
        )
        state_exists = bind.execute(
            sa.select(states.c.signal_id).where(states.c.signal_id == signal_id)
        ).first()
        if state_exists is None:
            bind.execute(
                states.insert().values(
                    signal_id=signal_id,
                    sync_status="deleted" if is_deleted else "synced",
                    assist_status="not_started",
                    reason_status="not_started",
                    daily_status=(
                        "excluded"
                        if is_analysis_excluded
                        else "included" if row["included_in_summary"] else "not_started"
                    ),
                    weekly_status=(
                        "excluded"
                        if is_analysis_excluded
                        else "included" if row["included_in_weekly"] else "not_started"
                    ),
                    journey_status=(
                        "excluded"
                        if is_analysis_excluded
                        else "included" if row["included_in_journey"] else "not_started"
                    ),
                    retry_count=0,
                    processing_version="v4_p0_02",
                )
            )

        policy_exists = bind.execute(
            sa.select(policies.c.signal_id).where(
                policies.c.signal_id == signal_id
            )
        ).first()
        if policy_exists is None:
            exclusion_reason = None
            if is_deleted:
                exclusion_reason = "signal_deleted"
            elif inaccurate:
                exclusion_reason = "inaccurate"
            elif privacy_level in {"sensitive", "excluded", "do_not_analyze"}:
                exclusion_reason = privacy_level
            bind.execute(
                policies.insert().values(
                    signal_id=signal_id,
                    privacy_level=privacy_level,
                    is_sensitive=privacy_level == "sensitive",
                    is_excluded=is_analysis_excluded,
                    do_not_analyze=is_analysis_excluded,
                    requires_user_confirmation=False,
                    confirmed_by_user=confirmation
                    in {"confirmed", "edited", "supplemented"},
                    inaccurate=inaccurate,
                    exclusion_reason=exclusion_reason,
                )
            )


def _backfill_weekly_reflections() -> None:
    bind = op.get_bind()
    metadata = sa.MetaData()
    weekly = sa.Table("weekly_insights", metadata, autoload_with=bind)
    reflections = sa.Table("reflection_results", metadata, autoload_with=bind)
    pipelines = sa.Table("pipeline_runs", metadata, autoload_with=bind)

    for row in bind.execute(sa.select(weekly)).mappings():
        week_start = str(row["week_start"])
        reflection_id = (
            f"refl_weekly_snapshot_{row['user_id']}_{week_start}_reflect_v1"
        )
        if bind.execute(
            sa.select(reflections.c.id).where(reflections.c.id == reflection_id)
        ).first() is None:
            content = {
                "key_insight": row["key_insight"],
                "patterns": row["top_patterns_json"],
                "frictions": row["top_frictions_json"],
                "best_action": row["best_action"],
                "opportunity_snapshot": row["opportunity_snapshot_json"],
            }
            # Some reflected SQLite JSON columns return encoded text for old
            # fixtures.  Normalize before handing the value to SQLAlchemy JSON.
            content = json.loads(json.dumps(content, default=str))
            bind.execute(
                reflections.insert().values(
                    id=reflection_id,
                    user_id=row["user_id"],
                    source_type="weekly_snapshot",
                    source_id=week_start,
                    reflection_type="reflect",
                    ai_level="L3",
                    content_json=content,
                    status="generated",
                    schema_version=1,
                    pipeline_version="v4_p0_05",
                    dirty=0,
                    is_stale=0,
                    generated_at=row["updated_at"],
                    created_at=row["created_at"],
                    updated_at=row["updated_at"],
                )
            )

        pipeline_id = f"pipe_weekly_snapshot_{row['user_id']}_{week_start}_v1"
        if bind.execute(
            sa.select(pipelines.c.id).where(pipelines.c.id == pipeline_id)
        ).first() is None:
            bind.execute(
                pipelines.insert().values(
                    id=pipeline_id,
                    user_id=row["user_id"],
                    pipeline_type="weekly_aggregation",
                    source_type="weekly_snapshot",
                    source_id=week_start,
                    status="completed",
                    started_at=row["created_at"],
                    finished_at=row["updated_at"],
                    pipeline_version="v4_p0_05",
                    retry_count=0,
                    can_retry=0,
                    created_at=row["created_at"],
                    updated_at=row["updated_at"],
                )
            )


OPERATIONAL_INDEXES: tuple[tuple[str, str, list[str]], ...] = (
    ("idx_captures_user_created_at", "captures", ["user_id", "created_at"]),
    ("ix_signal_processing_state_sync_status", "signal_processing_state", ["sync_status"]),
    ("ix_signal_processing_state_stages", "signal_processing_state", ["daily_status", "weekly_status", "journey_status"]),
    ("ix_signal_analysis_policy_privacy", "signal_analysis_policy", ["privacy_level"]),
    ("ix_signal_analysis_policy_flags", "signal_analysis_policy", ["inaccurate", "do_not_analyze", "is_sensitive", "is_excluded"]),
    ("idx_reflection_results_user_source", "reflection_results", ["user_id", "source_type", "source_id", "reflection_type", "status", "generated_at"]),
    ("idx_reflection_results_cache_state", "reflection_results", ["source_type", "source_id", "dirty", "is_stale", "status"]),
    ("idx_reflection_results_user_source_state", "reflection_results", ["user_id", "source_type", "source_id", "dirty", "is_stale", "generated_at"]),
    ("idx_pipeline_runs_user_source", "pipeline_runs", ["user_id", "source_type", "source_id", "pipeline_type", "status", "started_at"]),
    ("idx_pipeline_runs_retry", "pipeline_runs", ["status", "can_retry", "updated_at"]),
    ("idx_signal_cards_server_id", "signal_cards", ["server_id"]),
    ("ix_signal_cards_user_period_weekly", "signal_cards", ["user_id", "local_date", "included_in_weekly", "created_at"]),
    ("ix_signal_cards_user_period_journey", "signal_cards", ["user_id", "local_date", "included_in_journey", "created_at"]),
    ("idx_observations_user_status_date", "observations", ["user_id", "status", "source_period_start", "updated_at"]),
    ("idx_observations_ai_judgement", "observations", ["source_ai_judgement_id"]),
    ("idx_observation_signal_links_signal", "observation_signal_links", ["signal_id"]),
    ("idx_experiment_candidates_source", "experiment_candidates", ["source_type", "source_id", "user_id"]),
    ("idx_experiment_candidates_week", "experiment_candidates", ["user_id", "source_week_start", "status"]),
    ("idx_experiment_candidates_adopted", "experiment_candidates", ["adopted_experiment_id"]),
    ("idx_experiment_candidates_stale", "experiment_candidates", ["user_id", "source_week_start", "dirty", "is_stale", "status"]),
    ("idx_experiment_candidates_group", "experiment_candidates", ["candidate_group_id", "candidate_rank"]),
    ("idx_life_experiment_events_exp", "life_experiment_lifecycle_events", ["experiment_id", "event_date"]),
    ("idx_life_experiment_events_user_date", "life_experiment_lifecycle_events", ["user_id", "local_date"]),
    ("idx_life_experiment_events_user_period", "life_experiment_lifecycle_events", ["user_id", "local_date", "event_type"]),
    ("idx_life_experiment_rollups_user_week", "life_experiment_rollups", ["user_id", "source_week_start"]),
    ("idx_life_experiment_rollups_root", "life_experiment_rollups", ["root_experiment_id", "source_week_start"]),
    ("idx_life_experiment_rollups_user_period", "life_experiment_rollups", ["user_id", "source_week_start", "source_week_end", "updated_at"]),
    ("idx_trace_links_source", "trace_links", ["source_type", "source_id", "relation_type", "status"]),
    ("idx_trace_links_target", "trace_links", ["target_type", "target_id", "relation_type", "status"]),
    ("idx_trace_links_user_status", "trace_links", ["user_id", "status", "updated_at"]),
    ("idx_legacy_endpoint_counter", "legacy_endpoint_telemetry", ["counter_name", "created_at"]),
    ("idx_legacy_endpoint_endpoint", "legacy_endpoint_telemetry", ["endpoint", "created_at"]),
    ("idx_legacy_endpoint_user_hash", "legacy_endpoint_telemetry", ["user_id_hash"]),
    ("idx_legacy_endpoint_account_hash", "legacy_endpoint_telemetry", ["account_id_hash"]),
    ("idx_candidate_groups_read", "candidate_groups", ["user_id", "candidate_kind", "period_start", "status", "updated_at"]),
    ("idx_micro_action_candidates_group", "micro_action_candidates", ["candidate_group_id", "rank"]),
    ("idx_micro_action_candidates_read", "micro_action_candidates", ["user_id", "local_date", "status", "dirty", "is_stale", "rank"]),
)


def upgrade() -> None:
    # This is the bridge from both historical sources to one Alembic head.
    # Every create/index operation is deliberately conditional because some
    # deployments ran SQL 006-019 before Alembic became authoritative.
    _create_table_if_missing('accounts',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('apple_sub_hash', sa.String(), nullable=False),
    sa.Column('session_token_hash', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    _create_index_if_missing(op.f('ix_accounts_apple_sub_hash'), 'accounts', ['apple_sub_hash'], unique=True)
    _create_index_if_missing(op.f('ix_accounts_session_token_hash'), 'accounts', ['session_token_hash'], unique=False)
    _create_table_if_missing('account_aliases',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('account_id', sa.String(), nullable=False),
    sa.Column('local_user_id', sa.String(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('account_id', 'local_user_id', name='uq_account_local_user')
    )
    _create_index_if_missing(op.f('ix_account_aliases_account_id'), 'account_aliases', ['account_id'], unique=False)
    _create_index_if_missing(op.f('ix_account_aliases_local_user_id'), 'account_aliases', ['local_user_id'], unique=False)
    _create_table_if_missing('backup_bundles',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('account_id', sa.String(), nullable=False),
    sa.Column('schema_version', sa.Integer(), nullable=False),
    sa.Column('backup_version', sa.String(), nullable=False),
    sa.Column('device_id', sa.String(), nullable=True),
    sa.Column('payload', sa.JSON(), nullable=False),
    sa.Column('counts_json', sa.JSON(), nullable=False),
    sa.Column('restored_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('restore_device_id', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['account_id'], ['accounts.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_index_if_missing(op.f('ix_backup_bundles_account_id'), 'backup_bundles', ['account_id'], unique=False)
    _create_index_if_missing(op.f('ix_backup_bundles_device_id'), 'backup_bundles', ['device_id'], unique=False)
    _create_table_if_missing('life_experiment_lifecycle_events',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('experiment_id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('event_type', sa.String(), nullable=False),
    sa.Column('event_date', sa.DateTime(timezone=True), nullable=False),
    sa.Column('local_date', sa.Date(), nullable=False),
    sa.Column('source_type', sa.String(), nullable=True),
    sa.Column('source_id', sa.String(), nullable=True),
    sa.Column('status_from', sa.String(), nullable=True),
    sa.Column('status_to', sa.String(), nullable=True),
    sa.Column('payload', sa.JSON(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_table_if_missing('life_experiment_rollups',
    sa.Column('experiment_id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('root_experiment_id', sa.String(), nullable=False),
    sa.Column('parent_experiment_id', sa.String(), nullable=True),
    sa.Column('source_week_start', sa.Date(), nullable=False),
    sa.Column('source_week_end', sa.Date(), nullable=False),
    sa.Column('current_status', sa.String(), nullable=False),
    sa.Column('title', sa.String(), nullable=False),
    sa.Column('hypothesis', sa.Text(), nullable=False),
    sa.Column('suggested_action', sa.Text(), nullable=False),
    sa.Column('total_feedback_count', sa.Integer(), nullable=False),
    sa.Column('tried_count', sa.Integer(), nullable=False),
    sa.Column('helpful_count', sa.Integer(), nullable=False),
    sa.Column('not_helpful_count', sa.Integer(), nullable=False),
    sa.Column('adjusted_count', sa.Integer(), nullable=False),
    sa.Column('skipped_count', sa.Integer(), nullable=False),
    sa.Column('active_week_count', sa.Integer(), nullable=False),
    sa.Column('first_started_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('last_feedback_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('last_event_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('lineage', sa.JSON(), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('experiment_id')
    )
    _create_table_if_missing('model_usage_logs',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('feature_key', sa.String(), nullable=False),
    sa.Column('model_used', sa.String(), nullable=True),
    sa.Column('parser_version', sa.String(), nullable=True),
    sa.Column('prompt_version', sa.String(), nullable=True),
    sa.Column('input_tokens', sa.Integer(), nullable=False),
    sa.Column('output_tokens', sa.Integer(), nullable=False),
    sa.Column('cached_input_tokens', sa.Integer(), nullable=False),
    sa.Column('latency_ms', sa.Integer(), nullable=True),
    sa.Column('fallback_used', sa.Boolean(), nullable=False),
    sa.Column('quota_decision', sa.String(), nullable=False),
    sa.Column('cache_hit', sa.Boolean(), nullable=False),
    sa.Column('source_event_id', sa.String(), nullable=True),
    sa.Column('metadata_json', sa.JSON(), nullable=False),
    sa.Column('estimated_cost_usd', sa.Float(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_index_if_missing(op.f('ix_model_usage_logs_created_at'), 'model_usage_logs', ['created_at'], unique=False)
    _create_index_if_missing(op.f('ix_model_usage_logs_feature_key'), 'model_usage_logs', ['feature_key'], unique=False)
    _create_index_if_missing(op.f('ix_model_usage_logs_model_used'), 'model_usage_logs', ['model_used'], unique=False)
    _create_index_if_missing(op.f('ix_model_usage_logs_source_event_id'), 'model_usage_logs', ['source_event_id'], unique=False)
    _create_index_if_missing(op.f('ix_model_usage_logs_user_id'), 'model_usage_logs', ['user_id'], unique=False)
    _create_table_if_missing('observations',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('observation_text', sa.Text(), nullable=False),
    sa.Column('observation_type', sa.String(), nullable=False),
    sa.Column('confidence', sa.String(), nullable=False),
    sa.Column('status', sa.String(), nullable=False),
    sa.Column('source_period_start', sa.Date(), nullable=True),
    sa.Column('source_period_end', sa.Date(), nullable=True),
    sa.Column('created_by', sa.String(), nullable=False),
    sa.Column('source_ai_judgement_id', sa.String(), nullable=True),
    sa.Column('evidence_text', sa.Text(), nullable=True),
    sa.Column('suggested_pattern', sa.String(), nullable=True),
    sa.Column('suggested_life_chain_stage', sa.String(), nullable=True),
    sa.Column('user_adjustment_text', sa.Text(), nullable=True),
    sa.Column('confirmation_note', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('dismissed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('archived_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_table_if_missing('pipeline_runs',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('pipeline_type', sa.String(), nullable=False),
    sa.Column('source_type', sa.String(), nullable=False),
    sa.Column('source_id', sa.String(), nullable=False),
    sa.Column('status', sa.String(), nullable=False),
    sa.Column('started_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('finished_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('error_code', sa.String(), nullable=True),
    sa.Column('error_message', sa.Text(), nullable=True),
    sa.Column('input_hash', sa.Text(), nullable=True),
    sa.Column('output_hash', sa.Text(), nullable=True),
    sa.Column('pipeline_version', sa.String(), nullable=False),
    sa.Column('retry_count', sa.Integer(), nullable=False),
    sa.Column('can_retry', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_table_if_missing('quota_gate_events',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('feature_key', sa.String(), nullable=False),
    sa.Column('entitlement', sa.String(), nullable=False),
    sa.Column('period_type', sa.String(), nullable=False),
    sa.Column('period_start', sa.String(), nullable=False),
    sa.Column('limit_value', sa.Integer(), nullable=True),
    sa.Column('used_value', sa.Integer(), nullable=False),
    sa.Column('decision', sa.String(), nullable=False),
    sa.Column('source_event_id', sa.String(), nullable=True),
    sa.Column('metadata_json', sa.JSON(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_index_if_missing(op.f('ix_quota_gate_events_created_at'), 'quota_gate_events', ['created_at'], unique=False)
    _create_index_if_missing(op.f('ix_quota_gate_events_decision'), 'quota_gate_events', ['decision'], unique=False)
    _create_index_if_missing(op.f('ix_quota_gate_events_feature_key'), 'quota_gate_events', ['feature_key'], unique=False)
    _create_index_if_missing(op.f('ix_quota_gate_events_source_event_id'), 'quota_gate_events', ['source_event_id'], unique=False)
    _create_index_if_missing(op.f('ix_quota_gate_events_user_id'), 'quota_gate_events', ['user_id'], unique=False)
    _create_table_if_missing('reflection_results',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('source_type', sa.String(), nullable=False),
    sa.Column('source_id', sa.String(), nullable=False),
    sa.Column('reflection_type', sa.String(), nullable=False),
    sa.Column('ai_level', sa.String(), nullable=False),
    sa.Column('content_json', sa.JSON(), nullable=False),
    sa.Column('status', sa.String(), nullable=False),
    sa.Column('schema_version', sa.Integer(), nullable=False),
    sa.Column('prompt_version', sa.String(), nullable=True),
    sa.Column('model_version', sa.String(), nullable=True),
    sa.Column('pipeline_version', sa.String(), nullable=False),
    sa.Column('source_hash', sa.Text(), nullable=True),
    sa.Column('dirty', sa.Integer(), nullable=False),
    sa.Column('is_stale', sa.Integer(), nullable=False),
    sa.Column('stale_reason', sa.Text(), nullable=True),
    sa.Column('invalidated_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('generated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('confirmed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('superseded_by', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_table_if_missing('trace_links',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('source_type', sa.String(), nullable=False),
    sa.Column('source_id', sa.String(), nullable=False),
    sa.Column('target_type', sa.String(), nullable=False),
    sa.Column('target_id', sa.String(), nullable=False),
    sa.Column('relation_type', sa.String(), nullable=False),
    sa.Column('weight', sa.Float(), nullable=False),
    sa.Column('status', sa.String(), nullable=False),
    sa.Column('metadata_json', sa.JSON(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('source_type', 'source_id', 'target_type', 'target_id', 'relation_type', name='uq_trace_links_source_target_relation')
    )
    _create_table_if_missing('usage_counters',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('feature_key', sa.String(), nullable=False),
    sa.Column('period_type', sa.String(), nullable=False),
    sa.Column('period_start', sa.String(), nullable=False),
    sa.Column('count', sa.Integer(), nullable=False),
    sa.Column('token_input', sa.Integer(), nullable=False),
    sa.Column('token_output', sa.Integer(), nullable=False),
    sa.Column('token_cached_input', sa.Integer(), nullable=False),
    sa.Column('model_used', sa.String(), nullable=True),
    sa.Column('source_event_id', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    _create_index_if_missing(op.f('ix_usage_counters_source_event_id'), 'usage_counters', ['source_event_id'], unique=False)
    _create_index_if_missing(op.f('ix_usage_counters_user_id'), 'usage_counters', ['user_id'], unique=False)
    _create_table_if_missing('signal_cards',
    sa.Column('id', sa.String(), nullable=False),
    sa.Column('user_id', sa.String(), nullable=False),
    sa.Column('capture_id', sa.String(), nullable=True),
    sa.Column('raw_memory_id', sa.String(), nullable=True),
    sa.Column('source_type', sa.String(), nullable=False),
    sa.Column('client_id', sa.String(), nullable=True),
    sa.Column('server_id', sa.String(), nullable=True),
    sa.Column('raw_text', sa.Text(), nullable=False),
    sa.Column('raw_payload_json', sa.JSON(), nullable=False),
    sa.Column('ai_reply', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('local_date', sa.Date(), nullable=False),
    sa.Column('timezone', sa.String(), nullable=False),
    sa.Column('language', sa.String(), nullable=False),
    sa.Column('emotion', sa.String(), nullable=True),
    sa.Column('intensity', sa.Integer(), nullable=True),
    sa.Column('scene', sa.String(), nullable=True),
    sa.Column('friction', sa.String(), nullable=True),
    sa.Column('positive_signal', sa.String(), nullable=True),
    sa.Column('energy_load', sa.String(), nullable=True),
    sa.Column('linked_life_chain_stage', sa.JSON(), nullable=False),
    sa.Column('confidence_score', sa.Float(), nullable=True),
    sa.Column('user_confirmation', sa.String(), nullable=False),
    sa.Column('user_correction_json', sa.JSON(), nullable=False),
    sa.Column('included_in_summary', sa.Boolean(), nullable=False),
    sa.Column('included_in_weekly', sa.Boolean(), nullable=False),
    sa.Column('included_in_journey', sa.Boolean(), nullable=False),
    sa.Column('linked_experiment_id', sa.String(), nullable=True),
    sa.Column('parser_version', sa.String(), nullable=False),
    sa.Column('model_used', sa.String(), nullable=True),
    sa.Column('prompt_version', sa.String(), nullable=True),
    sa.Column('token_usage_json', sa.JSON(), nullable=False),
    sa.Column('privacy_level', sa.String(), nullable=False),
    sa.Column('schema_version', sa.Integer(), nullable=False),
    sa.Column('is_legacy', sa.Boolean(), nullable=False),
    sa.Column('migration_status', sa.String(), nullable=False),
    sa.Column('metadata_json', sa.JSON(), nullable=False),
    sa.Column('deleted_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('deletion_reason', sa.String(), nullable=True),
    sa.Column('tombstone_version', sa.Integer(), nullable=False),
    sa.Column('restored_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['capture_id'], ['captures.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['raw_memory_id'], ['raw_memories.id'], ondelete='SET NULL'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    )
    _create_index_if_missing(op.f('ix_signal_cards_capture_id'), 'signal_cards', ['capture_id'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_created_at'), 'signal_cards', ['created_at'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_deleted_at'), 'signal_cards', ['deleted_at'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_linked_experiment_id'), 'signal_cards', ['linked_experiment_id'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_local_date'), 'signal_cards', ['local_date'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_raw_memory_id'), 'signal_cards', ['raw_memory_id'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_source_type'), 'signal_cards', ['source_type'], unique=False)
    _create_index_if_missing(op.f('ix_signal_cards_user_id'), 'signal_cards', ['user_id'], unique=False)
    _create_table_if_missing('observation_signal_links',
    sa.Column('observation_id', sa.String(), nullable=False),
    sa.Column('signal_id', sa.String(), nullable=False),
    sa.Column('weight', sa.Float(), nullable=False),
    sa.Column('reason', sa.String(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['observation_id'], ['observations.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['signal_id'], ['signal_cards.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('observation_id', 'signal_id')
    )
    _create_table_if_missing('signal_analysis_policy',
    sa.Column('signal_id', sa.String(), nullable=False),
    sa.Column('privacy_level', sa.String(), nullable=False),
    sa.Column('is_sensitive', sa.Boolean(), nullable=False),
    sa.Column('is_excluded', sa.Boolean(), nullable=False),
    sa.Column('do_not_analyze', sa.Boolean(), nullable=False),
    sa.Column('requires_user_confirmation', sa.Boolean(), nullable=False),
    sa.Column('confirmed_by_user', sa.Boolean(), nullable=False),
    sa.Column('inaccurate', sa.Boolean(), nullable=False),
    sa.Column('exclusion_reason', sa.String(), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['signal_id'], ['signal_cards.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('signal_id')
    )
    _create_table_if_missing('signal_processing_state',
    sa.Column('signal_id', sa.String(), nullable=False),
    sa.Column('sync_status', sa.String(), nullable=False),
    sa.Column('assist_status', sa.String(), nullable=False),
    sa.Column('reason_status', sa.String(), nullable=False),
    sa.Column('daily_status', sa.String(), nullable=False),
    sa.Column('weekly_status', sa.String(), nullable=False),
    sa.Column('journey_status', sa.String(), nullable=False),
    sa.Column('last_processed_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('retry_count', sa.Integer(), nullable=False),
    sa.Column('processing_version', sa.String(), nullable=False),
    sa.Column('last_error', sa.Text(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=False),
    sa.ForeignKeyConstraint(['signal_id'], ['signal_cards.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('signal_id')
    )

    # Known column-level drift between the standalone SQL chain and current
    # models.  Every addition is safe on fresh, Alembic-only, and hybrid DBs.
    _add_column_if_missing(
        "signal_cards", sa.Column("client_id", sa.String(), nullable=True)
    )
    _add_column_if_missing(
        "signal_cards", sa.Column("server_id", sa.String(), nullable=True)
    )
    _add_column_if_missing(
        "signal_cards",
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
    )
    _add_column_if_missing(
        "signal_cards",
        sa.Column("deletion_reason", sa.String(), nullable=True),
    )
    _add_column_if_missing(
        "signal_cards",
        sa.Column(
            "tombstone_version",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
    )
    _add_column_if_missing(
        "signal_cards",
        sa.Column("restored_at", sa.DateTime(timezone=True), nullable=True),
    )
    _add_column_if_missing(
        "reflection_results",
        sa.Column(
            "pipeline_version",
            sa.String(),
            nullable=False,
            server_default="v4_p0_05",
        ),
    )
    _add_column_if_missing(
        "reflection_results", sa.Column("source_hash", sa.Text(), nullable=True)
    )
    _add_column_if_missing(
        "reflection_results",
        sa.Column("dirty", sa.Integer(), nullable=False, server_default="0"),
    )
    _add_column_if_missing(
        "reflection_results",
        sa.Column("is_stale", sa.Integer(), nullable=False, server_default="0"),
    )
    _add_column_if_missing(
        "reflection_results",
        sa.Column("stale_reason", sa.Text(), nullable=True),
    )
    _add_column_if_missing(
        "reflection_results",
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column(
            "dirty", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column(
            "is_stale", sa.Boolean(), nullable=False, server_default=sa.false()
        ),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column("stale_reason", sa.Text(), nullable=True),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column("candidate_group_id", sa.String(), nullable=True),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column(
            "candidate_rank", sa.Integer(), nullable=False, server_default="1"
        ),
    )
    _add_column_if_missing(
        "experiment_candidates",
        sa.Column("source_hash", sa.String(), nullable=True),
    )
    _add_column_if_missing(
        "weekly_insights",
        sa.Column(
            "chart_data_json",
            sa.JSON(),
            nullable=False,
            server_default=sa.text("'[]'"),
        ),
    )

    op.execute(
        sa.text(
            "UPDATE signal_cards "
            "SET client_id = COALESCE(client_id, id), "
            "server_id = COALESCE(server_id, id) "
            "WHERE client_id IS NULL OR server_id IS NULL"
        )
    )
    _backfill_signal_state_and_policy()
    _backfill_weekly_reflections()
    _deduplicate_usage_counters()

    _ensure_unique_index(
        "signal_cards",
        "uq_signal_cards_user_client_id",
        ["user_id", "client_id"],
    )
    _ensure_unique_index(
        "usage_counters",
        "uq_usage_counters_user_feature_period",
        ["user_id", "feature_key", "period_type", "period_start"],
    )
    for obsolete_index in (
        "ix_usage_counters_feature_key",
        "ix_usage_counters_period_type",
        "ix_usage_counters_period_start",
    ):
        _drop_index_if_exists("usage_counters", obsolete_index)
    _ensure_not_nullable("reflection_version_registry", "created_at")
    _ensure_not_nullable("reflection_version_registry", "updated_at")
    _ensure_not_nullable("legacy_endpoint_telemetry", "created_at")

    # Indexes still declared as single-column model indexes on the pre-007
    # schema are added without replacing established compound indexes.
    _create_index_if_missing(op.f('ix_desires_user_id'), 'desires', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_experiments_opportunity_id'), 'experiments', ['opportunity_id'], unique=False)
    _create_index_if_missing(op.f('ix_experiments_user_id'), 'experiments', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_followup_answers_user_id'), 'followup_answers', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_followup_questions_user_id'), 'followup_questions', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_frictions_user_id'), 'frictions', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_opportunities_user_id'), 'opportunities', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_patterns_user_id'), 'patterns', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_raw_memories_user_id'), 'raw_memories', ['user_id'], unique=False)
    _create_index_if_missing(op.f('ix_weekly_insights_user_id'), 'weekly_insights', ['user_id'], unique=False)

    for index_name, table_name, columns in OPERATIONAL_INDEXES:
        _create_index_if_missing(index_name, table_name, columns, unique=False)


def downgrade() -> None:
    raise RuntimeError("0007 schema reconciliation is intentionally irreversible")
