from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from uuid import uuid4

import pytest
import sqlalchemy as sa
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from sqlalchemy.engine import URL, make_url

from tests._migration_test_support import (
    ALEMBIC_INI,
    BACKEND_ROOT,
    LEGACY_SQL_ROOT,
    assert_alembic_succeeded,
    head_revision,
)


_DATABASE_URL_OPT_IN = "POSTGRES_MIGRATION_TEST_USE_DATABASE_URL"


def _postgres_test_url() -> str | None:
    """Return the explicitly authorised PostgreSQL migration-test database.

    ``DATABASE_URL`` is deliberately ignored unless the opt-in flag is set.
    This test creates and drops only a unique temporary schema, but requiring
    an explicit opt-in still prevents an accidental run against an app DB.
    """

    value = os.getenv("POSTGRES_MIGRATION_TEST_URL")
    if value:
        return value
    if os.getenv(_DATABASE_URL_OPT_IN, "").lower() in {"1", "true", "yes"}:
        return os.getenv("DATABASE_URL")
    return None


def _psycopg_url(value: str) -> URL:
    url = make_url(value)
    if url.drivername == "postgres":
        url = url.set(drivername="postgresql+psycopg")
    if url.get_backend_name() != "postgresql":
        pytest.fail("PostgreSQL migration contract requires a PostgreSQL URL")
    if url.drivername == "postgresql":
        url = url.set(drivername="postgresql+psycopg")
    return url


def _schema_scoped_url(url: URL, schema_name: str) -> URL:
    # libpq's startup option applies before SQLAlchemy asks current_schema(),
    # so inspection/autogenerate correctly treats this as the default schema.
    return url.update_query_dict(
        {"options": f"-csearch_path={schema_name}"},
        append=False,
    )


def _run_alembic(database_url: URL, *arguments: str) -> None:
    environment = os.environ.copy()
    environment["DATABASE_URL"] = database_url.render_as_string(
        hide_password=False
    )
    environment["PYTHONPATH"] = os.pathsep.join(
        value
        for value in (str(BACKEND_ROOT), environment.get("PYTHONPATH"))
        if value
    )
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "alembic",
            "-c",
            str(ALEMBIC_INI),
            *arguments,
        ],
        cwd=BACKEND_ROOT,
        env=environment,
        capture_output=True,
        text=True,
        # Public staging proxies make the many introspection/DDL round trips
        # much slower than CI's local PostgreSQL service. Keep this high enough
        # for an auditable remote contract run without weakening assertions.
        timeout=600,
        check=False,
    )
    assert_alembic_succeeded(result)


def _execute_script(connection: sa.Connection, sql: str) -> None:
    """Execute a PostgreSQL script verbatim, without SQLite normalization."""

    driver_connection = connection.connection.driver_connection
    with driver_connection.cursor() as cursor:
        cursor.execute(sql, prepare=False)


def _apply_real_legacy_sql(
    engine: sa.Engine,
    *,
    first: int,
    last: int,
) -> None:
    scripts = {
        int(path.name[:3]): path
        for path in LEGACY_SQL_ROOT.glob("[0-9][0-9][0-9]_*.sql")
    }
    missing = set(range(first, last + 1)) - scripts.keys()
    assert not missing, f"missing legacy SQL migrations: {sorted(missing)}"
    for number in range(first, last + 1):
        with engine.begin() as connection:
            _execute_script(connection, scripts[number].read_text())


def _seed_alembic_0002(engine: sa.Engine) -> None:
    with engine.begin() as connection:
        _execute_script(
            connection,
            """
            INSERT INTO users(id) VALUES ('pg-legacy-user');
            INSERT INTO captures(id, user_id, content, input_mode, tag_hint)
            VALUES (
              'pg-legacy-capture', 'pg-legacy-user',
              '迁移前 PostgreSQL 记录', 'text', 'keep-me'
            );
            INSERT INTO raw_memories(
              id, user_id, capture_id, source, content, metadata_json
            ) VALUES (
              'pg-legacy-memory', 'pg-legacy-user', 'pg-legacy-capture',
              'capture', 'raw memory survives', '{"legacy": true}'::json
            );
            INSERT INTO weekly_insights(
              id, user_id, week_start, week_end, key_insight,
              top_patterns_json, top_frictions_json, best_action,
              opportunity_snapshot_json
            ) VALUES (
              'pg-legacy-weekly', 'pg-legacy-user', '2026-06-29',
              '2026-07-05', 'legacy weekly survives', '["pattern"]'::json,
              '["friction"]'::json, 'one small action',
              '{"score": 0.7}'::json
            );
            """,
        )


def _seed_after_sql_006(engine: sa.Engine) -> None:
    with engine.begin() as connection:
        _execute_script(
            connection,
            """
            INSERT INTO signal_cards(
              id, user_id, capture_id, raw_memory_id, source_type, raw_text,
              raw_payload_json, created_at, local_date, timezone, language,
              privacy_level, user_confirmation
            ) VALUES (
              'pg-legacy-signal', 'pg-legacy-user', 'pg-legacy-capture',
              'pg-legacy-memory', 'text', '真实 PostgreSQL Signal',
              '{"source": "006"}'::jsonb, '2026-07-02 08:30:00+09',
              '2026-07-02', 'Asia/Tokyo', 'zh-Hans', 'private', 'confirmed'
            );

            INSERT INTO usage_counters(
              id, user_id, feature_key, period_type, period_start, count,
              token_input, token_output, token_cached_input, created_at,
              updated_at
            ) VALUES
              (
                'pg-duplicate-usage-a', 'pg-legacy-user',
                'migration_dedup_probe', 'week', '2026-06-29',
                2, 70, 20, 8, '2026-07-01 09:00:00+09',
                '2026-07-01 09:00:00+09'
              ),
              (
                'pg-duplicate-usage-b', 'pg-legacy-user',
                'migration_dedup_probe', 'week', '2026-06-29',
                5, 40, 35, 11, '2026-07-02 09:00:00+09',
                '2026-07-02 09:00:00+09'
              );
            """,
        )


def _seed_after_sql_019(engine: sa.Engine) -> None:
    with engine.begin() as connection:
        _execute_script(
            connection,
            """
            INSERT INTO observations(
              id, user_id, observation_text, source_ai_judgement_id
            ) VALUES (
              'pg-legacy-observation', 'pg-legacy-user',
              'observation survives', 'pg-ai-judgement'
            );
            INSERT INTO observation_signal_links(
              observation_id, signal_id, weight, reason
            ) VALUES (
              'pg-legacy-observation', 'pg-legacy-signal', 0.8,
              'legacy evidence'
            );
            INSERT INTO candidate_groups(
              id, user_id, candidate_kind, period_start, period_end,
              source_hash, eligible_signal_count
            ) VALUES (
              'pg-legacy-candidate-group', 'pg-legacy-user', 'micro_action',
              '2026-07-02', '2026-07-02', 'pg-legacy-source', 3
            );
            INSERT INTO micro_action_candidates(
              id, candidate_group_id, user_id, local_date, rank, title,
              source_hash
            ) VALUES (
              'pg-legacy-micro-candidate', 'pg-legacy-candidate-group',
              'pg-legacy-user', '2026-07-02', 1,
              'candidate survives', 'pg-legacy-source'
            );
            INSERT INTO legacy_endpoint_telemetry(
              id, counter_name, endpoint, user_id_hash
            ) VALUES (
              'pg-legacy-telemetry', 'legacy_call_count',
              '/api/v1/ai/deep-weekly', 'safe-user-hash'
            );

            -- These two rows intentionally arrive after legacy SQL 007. They
            -- exercise Alembic 0007's authoritative policy/state backfill,
            -- instead of inheriting the older SQL backfill behavior.
            INSERT INTO signal_cards(
              id, user_id, source_type, raw_text, raw_payload_json, created_at,
              local_date, timezone, language, privacy_level, user_confirmation
            ) VALUES
              (
                'pg-sensitive-signal', 'pg-legacy-user', 'text',
                'sensitive signal', '{}'::jsonb,
                '2026-07-03 08:30:00+09', '2026-07-03', 'Asia/Tokyo',
                'zh-Hans', 'sensitive', 'confirmed'
              ),
              (
                'pg-deleted-signal', 'pg-legacy-user', 'text',
                'deleted signal', '{}'::jsonb,
                '2026-07-03 09:30:00+09', '2026-07-03', 'Asia/Tokyo',
                'zh-Hans', 'private', 'confirmed'
              );
            """,
        )


def _mark_tombstone_after_0003(engine: sa.Engine) -> None:
    with engine.begin() as connection:
        connection.execute(
            sa.text(
                "UPDATE signal_cards "
                "SET deleted_at = '2026-07-04 10:00:00+09', "
                "deletion_reason = 'postgres migration contract', "
                "tombstone_version = 1 "
                "WHERE id = 'pg-deleted-signal'"
            )
        )


def _metadata_diffs(engine: sa.Engine) -> list[object]:
    from app.core.db import Base
    import app.models  # noqa: F401

    with engine.connect() as connection:
        context = MigrationContext.configure(
            connection,
            opts={
                "compare_type": True,
                "compare_server_default": False,
            },
        )
        return compare_metadata(context, Base.metadata)


def _assert_revision_and_sentinels(engine: sa.Engine) -> None:
    with engine.connect() as connection:
        assert connection.scalar(
            sa.text("SELECT version_num FROM alembic_version")
        ) == head_revision()
        assert connection.execute(
            sa.text(
                "SELECT content, input_mode, tag_hint "
                "FROM captures WHERE id = 'pg-legacy-capture'"
            )
        ).one() == ("迁移前 PostgreSQL 记录", "text", "keep-me")
        assert connection.scalar(
            sa.text(
                "SELECT observation_text FROM observations "
                "WHERE id = 'pg-legacy-observation'"
            )
        ) == "observation survives"
        assert connection.scalar(
            sa.text(
                "SELECT title FROM micro_action_candidates "
                "WHERE id = 'pg-legacy-micro-candidate'"
            )
        ) == "candidate survives"
        assert connection.execute(
            sa.text(
                "SELECT raw_text, client_id, server_id "
                "FROM signal_cards WHERE id = 'pg-legacy-signal'"
            )
        ).one() == (
            "真实 PostgreSQL Signal",
            "pg-legacy-signal",
            "pg-legacy-signal",
        )
        assert connection.execute(
            sa.text(
                "SELECT sync_status, weekly_status, journey_status "
                "FROM signal_processing_state "
                "WHERE signal_id = 'pg-legacy-signal'"
            )
        ).one() == ("synced", "not_started", "not_started")
        assert connection.execute(
            sa.text(
                "SELECT s.sync_status, s.daily_status, s.weekly_status, "
                "s.journey_status, p.is_sensitive, p.is_excluded, "
                "p.do_not_analyze, p.exclusion_reason "
                "FROM signal_processing_state s "
                "JOIN signal_analysis_policy p USING (signal_id) "
                "WHERE s.signal_id = 'pg-sensitive-signal'"
            )
        ).one() == (
            "synced",
            "excluded",
            "excluded",
            "excluded",
            True,
            True,
            True,
            "sensitive",
        )
        assert connection.execute(
            sa.text(
                "SELECT s.sync_status, s.daily_status, s.weekly_status, "
                "s.journey_status, p.is_excluded, p.do_not_analyze, "
                "p.exclusion_reason "
                "FROM signal_processing_state s "
                "JOIN signal_analysis_policy p USING (signal_id) "
                "WHERE s.signal_id = 'pg-deleted-signal'"
            )
        ).one() == (
            "deleted",
            "excluded",
            "excluded",
            "excluded",
            True,
            True,
            "signal_deleted",
        )
        assert connection.execute(
            sa.text(
                "SELECT count, token_input, token_output, token_cached_input "
                "FROM usage_counters "
                "WHERE user_id = 'pg-legacy-user' "
                "AND feature_key = 'migration_dedup_probe'"
            )
        ).one() == (7, 110, 55, 19)


def test_real_postgres_legacy_sql_006_019_upgrades_to_exact_head() -> None:
    configured_url = _postgres_test_url()
    if not configured_url:
        pytest.skip(
            "set POSTGRES_MIGRATION_TEST_URL to run the PostgreSQL "
            "legacy-to-head contract"
        )

    admin_url = _psycopg_url(configured_url)
    schema_name = f"migration_contract_{uuid4().hex}"
    scoped_url = _schema_scoped_url(admin_url, schema_name)
    admin_engine = sa.create_engine(admin_url, future=True)
    scoped_engine: sa.Engine | None = None
    try:
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(f'CREATE SCHEMA "{schema_name}"')

        scoped_engine = sa.create_engine(scoped_url, future=True)
        with scoped_engine.connect() as connection:
            assert connection.scalar(sa.text("SELECT current_schema()")) == schema_name

        _run_alembic(scoped_url, "upgrade", "0002_analytics")
        _seed_alembic_0002(scoped_engine)
        _apply_real_legacy_sql(scoped_engine, first=6, last=6)
        _seed_after_sql_006(scoped_engine)
        _apply_real_legacy_sql(scoped_engine, first=7, last=19)
        _seed_after_sql_019(scoped_engine)

        _run_alembic(scoped_url, "upgrade", "0003_signal_soft_delete")
        _mark_tombstone_after_0003(scoped_engine)
        _run_alembic(scoped_url, "upgrade", "head")

        _assert_revision_and_sentinels(scoped_engine)
        assert _metadata_diffs(scoped_engine) == []
    finally:
        if scoped_engine is not None:
            scoped_engine.dispose()
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(
                f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE'
            )
        admin_engine.dispose()


def test_postgres_deployed_0007_upgrades_to_exact_head() -> None:
    """Prove 0008 repairs databases that already deployed the former head."""

    configured_url = _postgres_test_url()
    if not configured_url:
        pytest.skip(
            "set POSTGRES_MIGRATION_TEST_URL to run the PostgreSQL "
            "0007-to-head contract"
        )

    admin_url = _psycopg_url(configured_url)
    schema_name = f"migration_contract_{uuid4().hex}"
    scoped_url = _schema_scoped_url(admin_url, schema_name)
    admin_engine = sa.create_engine(admin_url, future=True)
    scoped_engine: sa.Engine | None = None
    try:
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(f'CREATE SCHEMA "{schema_name}"')
        scoped_engine = sa.create_engine(scoped_url, future=True)

        _run_alembic(scoped_url, "upgrade", "0007_schema_reconcile")
        with scoped_engine.begin() as connection:
            connection.execute(
                sa.text(
                    "INSERT INTO users(id) VALUES ('pg-0007-user')"
                )
            )
            connection.execute(
                sa.text(
                    "INSERT INTO usage_counters("
                    "id, user_id, feature_key, period_type, period_start, "
                    "count, token_input, token_output, token_cached_input"
                    ") VALUES ("
                    "'pg-0007-usage', 'pg-0007-user', 'schema_probe', "
                    "'week', '2026-07-13', 0, 0, 0, 0"
                    ")"
                )
            )

        _run_alembic(scoped_url, "upgrade", "head")

        _assert_revision_and_0007_sentinel(scoped_engine)
        assert _metadata_diffs(scoped_engine) == []
    finally:
        if scoped_engine is not None:
            scoped_engine.dispose()
        with admin_engine.begin() as connection:
            connection.exec_driver_sql(
                f'DROP SCHEMA IF EXISTS "{schema_name}" CASCADE'
            )
        admin_engine.dispose()


def _assert_revision_and_0007_sentinel(engine: sa.Engine) -> None:
    with engine.connect() as connection:
        assert connection.scalar(
            sa.text("SELECT version_num FROM alembic_version")
        ) == head_revision()
        assert connection.scalar(
            sa.text(
                "SELECT feature_key FROM usage_counters "
                "WHERE id = 'pg-0007-usage'"
            )
        ) == "schema_probe"
