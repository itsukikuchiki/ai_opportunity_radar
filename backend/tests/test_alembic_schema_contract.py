from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tests._migration_test_support import (
    apply_real_legacy_sql_006,
    apply_real_legacy_sql_range,
    assert_alembic_succeeded,
    current_revision,
    head_revision,
    metadata_schema_diffs,
    run_alembic,
    sqlite_schema_fingerprint,
)


def _upgrade(database_path: Path, revision: str) -> None:
    assert_alembic_succeeded(
        run_alembic(database_path, "upgrade", revision)
    )


def _seed_0002_data(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("INSERT INTO users(id) VALUES (?)", ("legacy-user",))
        connection.execute(
            """
            INSERT INTO captures(id, user_id, content, input_mode, tag_hint)
            VALUES (?, ?, ?, ?, ?)
            """,
            (
                "legacy-capture",
                "legacy-user",
                "迁移前的真实记录",
                "text",
                "keep-me",
            ),
        )
        connection.execute(
            """
            INSERT INTO raw_memories(
              id, user_id, capture_id, source, content, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-memory",
                "legacy-user",
                "legacy-capture",
                "capture",
                "data must survive",
                json.dumps({"legacy": True}),
            ),
        )
        connection.execute(
            """
            INSERT INTO analytics_events(
              id, user_id, event_name, event_date, properties_json,
              numeric_value
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-event",
                "legacy-user",
                "migration_probe",
                "2026-07-01",
                json.dumps({"source": "0002"}),
                7.0,
            ),
        )
        connection.execute(
            """
            INSERT INTO user_subscriptions(
              user_id, product_id, status, environment, reason
            ) VALUES (?, ?, ?, ?, ?)
            """,
            (
                "legacy-user",
                "signalpath.pro.yearly",
                "active",
                "Sandbox",
                "verified_before_migration",
            ),
        )
        connection.commit()


def _assert_0002_data_preserved(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        assert connection.execute(
            "SELECT content, input_mode, tag_hint FROM captures WHERE id = ?",
            ("legacy-capture",),
        ).fetchone() == ("迁移前的真实记录", "text", "keep-me")
        assert connection.execute(
            "SELECT content, metadata_json FROM raw_memories WHERE id = ?",
            ("legacy-memory",),
        ).fetchone() == ("data must survive", '{"legacy": true}')
        assert connection.execute(
            "SELECT event_name, numeric_value FROM analytics_events WHERE id = ?",
            ("legacy-event",),
        ).fetchone() == ("migration_probe", 7.0)
        assert connection.execute(
            """
            SELECT product_id, status, environment, reason
            FROM user_subscriptions WHERE user_id = ?
            """,
            ("legacy-user",),
        ).fetchone() == (
            "signalpath.pro.yearly",
            "active",
            "Sandbox",
            "verified_before_migration",
        )


def _seed_raw_sql_006_data(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("INSERT INTO users(id) VALUES (?)", ("sql-user",))
        connection.execute(
            """
            INSERT INTO captures(id, user_id, content, input_mode)
            VALUES (?, ?, ?, ?)
            """,
            ("sql-capture", "sql-user", "standalone SQL data", "voice"),
        )
        connection.execute(
            """
            INSERT INTO raw_memories(
              id, user_id, capture_id, source, content, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?)
            """,
            (
                "sql-memory",
                "sql-user",
                "sql-capture",
                "capture",
                "raw SQL memory",
                json.dumps({"fixture": "006"}),
            ),
        )
        connection.execute(
            """
            INSERT INTO signal_cards(
              id, user_id, capture_id, raw_memory_id, source_type, raw_text,
              created_at, local_date, timezone, language, privacy_level,
              user_confirmation
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "sql-signal",
                "sql-user",
                "sql-capture",
                "sql-memory",
                "voice",
                "原始 Signal 不可丢失",
                "2026-07-02 08:30:00",
                "2026-07-02",
                "Asia/Tokyo",
                "zh-Hans",
                "private",
                "confirmed",
            ),
        )
        connection.execute(
            """
            INSERT INTO usage_counters(
              id, user_id, feature_key, period_type, period_start, count,
              token_input, token_output, source_event_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "sql-usage",
                "sql-user",
                "weekly_reflection",
                "week",
                "2026-06-29",
                3,
                120,
                40,
                "source-before-alembic",
            ),
        )
        connection.commit()


def _assert_raw_sql_006_data_preserved(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        assert connection.execute(
            """
            SELECT raw_text, timezone, language, user_confirmation,
                   client_id, server_id
            FROM signal_cards WHERE id = ?
            """,
            ("sql-signal",),
        ).fetchone() == (
            "原始 Signal 不可丢失",
            "Asia/Tokyo",
            "zh-Hans",
            "confirmed",
            "sql-signal",
            "sql-signal",
        )
        assert connection.execute(
            """
            SELECT count, token_input, token_output, source_event_id
            FROM usage_counters WHERE id = ?
            """,
            ("sql-usage",),
        ).fetchone() == (3, 120, 40, "source-before-alembic")
        # The unified chain must also perform the 007 policy/state backfill.
        assert connection.execute(
            """
            SELECT sync_status, daily_status, weekly_status, journey_status
            FROM signal_processing_state WHERE signal_id = ?
            """,
            ("sql-signal",),
        ).fetchone() == (
            "synced",
            "not_started",
            "not_started",
            "not_started",
        )
        assert connection.execute(
            """
            SELECT privacy_level, confirmed_by_user, inaccurate
            FROM signal_analysis_policy WHERE signal_id = ?
            """,
            ("sql-signal",),
        ).fetchone() == ("private", 1, 0)


def _seed_duplicate_raw_sql_usage_counters(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.executemany(
            """
            INSERT INTO usage_counters(
              id, user_id, feature_key, period_type, period_start, count,
              token_input, token_output, token_cached_input, created_at,
              updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                (
                    "duplicate-usage-a",
                    "sql-user",
                    "migration_dedup_probe",
                    "week",
                    "2026-06-29",
                    2,
                    70,
                    20,
                    8,
                    "2026-07-01 09:00:00",
                    "2026-07-01 09:00:00",
                ),
                (
                    "duplicate-usage-b",
                    "sql-user",
                    "migration_dedup_probe",
                    "week",
                    "2026-06-29",
                    5,
                    40,
                    35,
                    11,
                    "2026-07-02 09:00:00",
                    "2026-07-02 09:00:00",
                ),
            ),
        )
        connection.commit()


def _named_index(
    connection: sqlite3.Connection,
    table_name: str,
    index_name: str,
) -> tuple[bool, tuple[str, ...]]:
    index_row = next(
        row
        for row in connection.execute(f'PRAGMA index_list("{table_name}")')
        if row[1] == index_name
    )
    columns = tuple(
        row[2]
        for row in connection.execute(f'PRAGMA index_info("{index_name}")')
    )
    return bool(index_row[2]), columns


def _foreign_key_actions(
    connection: sqlite3.Connection,
    table_name: str,
) -> dict[tuple[str, str, str], str]:
    return {
        (row[3], row[2], row[4]): str(row[6]).upper()
        for row in connection.execute(
            f'PRAGMA foreign_key_list("{table_name}")'
        )
    }


def _insert_signal(
    connection: sqlite3.Connection,
    *,
    signal_id: str,
    client_id: str | None,
    capture_id: str | None = None,
    raw_memory_id: str | None = None,
) -> None:
    connection.execute(
        """
        INSERT INTO signal_cards(
          id, user_id, capture_id, raw_memory_id, source_type, client_id,
          raw_text, created_at, local_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            signal_id,
            "sql-user",
            capture_id,
            raw_memory_id,
            "text",
            client_id,
            f"signal {signal_id}",
            "2026-07-03 09:00:00",
            "2026-07-03",
        ),
    )


def _seed_weekly_before_legacy_backfill(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        connection.execute(
            """
            INSERT INTO weekly_insights(
              id, user_id, week_start, week_end, key_insight,
              top_patterns_json, top_frictions_json, best_action,
              opportunity_snapshot_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "sql-weekly",
                "sql-user",
                "2026-06-29",
                "2026-07-05",
                "legacy weekly insight",
                json.dumps(["pattern-a"]),
                json.dumps(["friction-a"]),
                "one small action",
                json.dumps({"score": 0.7}),
            ),
        )
        connection.commit()


def _seed_legacy_019_sentinels(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute(
            """
            INSERT INTO observations(
              id, user_id, observation_text, source_ai_judgement_id
            ) VALUES (?, ?, ?, ?)
            """,
            (
                "legacy-observation",
                "sql-user",
                "sentinel observation",
                "legacy-ai-judgement",
            ),
        )
        connection.execute(
            """
            INSERT INTO observation_signal_links(
              observation_id, signal_id, weight, reason
            ) VALUES (?, ?, ?, ?)
            """,
            (
                "legacy-observation",
                "sql-signal",
                0.8,
                "migration sentinel",
            ),
        )
        connection.execute(
            """
            INSERT INTO experiment_candidates(
              id, user_id, source_type, source_id, source_week_start,
              source_week_end, title, hypothesis, suggested_action,
              source_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-experiment-candidate",
                "sql-user",
                "weekly_reflection",
                "sql-weekly",
                "2026-06-29",
                "2026-07-05",
                "candidate survives",
                "migration is lossless",
                "upgrade head",
                "legacy-experiment-source",
            ),
        )
        connection.execute(
            """
            INSERT INTO life_experiment_lifecycle_events(
              id, experiment_id, user_id, event_type, event_date, local_date,
              payload
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-life-event",
                "legacy-life-experiment",
                "sql-user",
                "adopted",
                "2026-07-01 10:00:00",
                "2026-07-01",
                json.dumps({"source": "019"}),
            ),
        )
        connection.execute(
            """
            INSERT INTO life_experiment_rollups(
              experiment_id, user_id, root_experiment_id, source_week_start,
              source_week_end, current_status, title, hypothesis,
              suggested_action, lineage
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-life-experiment",
                "sql-user",
                "legacy-life-experiment",
                "2026-06-29",
                "2026-07-05",
                "active",
                "rollup survives",
                "migration is lossless",
                "keep going",
                json.dumps(["legacy-life-experiment"]),
            ),
        )
        connection.execute(
            """
            INSERT INTO trace_links(
              id, user_id, source_type, source_id, target_type, target_id,
              relation_type, metadata_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-trace",
                "sql-user",
                "signal",
                "sql-signal",
                "observation",
                "legacy-observation",
                "supports",
                json.dumps({"source": "019"}),
            ),
        )
        connection.execute(
            """
            INSERT INTO legacy_endpoint_telemetry(
              id, counter_name, endpoint, user_id_hash
            ) VALUES (?, ?, ?, ?)
            """,
            (
                "legacy-telemetry",
                "legacy_call_count",
                "/api/v1/ai/deep-weekly",
                "safe-user-hash",
            ),
        )
        connection.execute(
            """
            INSERT INTO candidate_groups(
              id, user_id, candidate_kind, period_start, period_end,
              source_hash, eligible_signal_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-candidate-group",
                "sql-user",
                "micro_action",
                "2026-07-02",
                "2026-07-02",
                "legacy-candidate-source",
                3,
            ),
        )
        connection.execute(
            """
            INSERT INTO micro_action_candidates(
              id, candidate_group_id, user_id, local_date, rank, title,
              source_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "legacy-micro-candidate",
                "legacy-candidate-group",
                "sql-user",
                "2026-07-02",
                1,
                "micro candidate survives",
                "legacy-candidate-source",
            ),
        )
        connection.commit()


def _assert_legacy_019_sentinels_preserved(database_path: Path) -> None:
    with sqlite3.connect(database_path) as connection:
        # 008/009 data backfills must survive the authoritative reconciliation.
        reflection = connection.execute(
            """
            SELECT source_type, source_id, status, pipeline_version
            FROM reflection_results
            WHERE user_id = ? AND source_type = 'weekly_snapshot'
            """,
            ("sql-user",),
        ).fetchone()
        assert reflection == (
            "weekly_snapshot",
            "2026-06-29",
            "generated",
            "v4_p0_05",
        )
        pipeline = connection.execute(
            """
            SELECT pipeline_type, source_id, status, pipeline_version
            FROM pipeline_runs WHERE user_id = ?
            """,
            ("sql-user",),
        ).fetchone()
        assert pipeline == (
            "weekly_aggregation",
            "2026-06-29",
            "completed",
            "v4_p0_05",
        )
        assert connection.execute(
            "SELECT observation_text FROM observations WHERE id = ?",
            ("legacy-observation",),
        ).fetchone() == ("sentinel observation",)
        assert connection.execute(
            "SELECT title FROM experiment_candidates WHERE id = ?",
            ("legacy-experiment-candidate",),
        ).fetchone() == ("candidate survives",)
        assert connection.execute(
            "SELECT event_type FROM life_experiment_lifecycle_events WHERE id = ?",
            ("legacy-life-event",),
        ).fetchone() == ("adopted",)
        assert connection.execute(
            "SELECT title FROM life_experiment_rollups WHERE experiment_id = ?",
            ("legacy-life-experiment",),
        ).fetchone() == ("rollup survives",)
        assert connection.execute(
            "SELECT relation_type FROM trace_links WHERE id = ?",
            ("legacy-trace",),
        ).fetchone() == ("supports",)
        assert connection.execute(
            "SELECT counter_name FROM legacy_endpoint_telemetry WHERE id = ?",
            ("legacy-telemetry",),
        ).fetchone() == ("legacy_call_count",)
        assert connection.execute(
            "SELECT title FROM micro_action_candidates WHERE id = ?",
            ("legacy-micro-candidate",),
        ).fetchone() == ("micro candidate survives",)


def test_fresh_database_upgrades_to_head_and_matches_model_metadata(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "fresh-to-head.sqlite"

    _upgrade(database_path, "head")

    assert current_revision(database_path) == head_revision()
    assert metadata_schema_diffs(database_path) == []
    first_schema = sqlite_schema_fingerprint(database_path)
    _upgrade(database_path, "head")
    assert sqlite_schema_fingerprint(database_path) == first_schema


def test_0002_database_upgrades_without_losing_existing_data(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "0002-to-head.sqlite"
    _upgrade(database_path, "0002_analytics")
    _seed_0002_data(database_path)

    _upgrade(database_path, "head")

    assert current_revision(database_path) == head_revision()
    _assert_0002_data_preserved(database_path)
    assert metadata_schema_diffs(database_path) == []
    first_schema = sqlite_schema_fingerprint(database_path)
    _upgrade(database_path, "head")
    assert sqlite_schema_fingerprint(database_path) == first_schema
    _assert_0002_data_preserved(database_path)


def test_alembic_0006_database_upgrades_without_losing_candidate_data(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "0006-to-head.sqlite"
    _upgrade(database_path, "0006_candidate_planning")
    with sqlite3.connect(database_path) as connection:
        connection.execute("INSERT INTO users(id) VALUES (?)", ("candidate-user",))
        connection.execute(
            """
            INSERT INTO candidate_groups(
              id, user_id, candidate_kind, period_start, period_end,
              source_hash, eligible_signal_count
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                "candidate-group-before-head",
                "candidate-user",
                "micro_action",
                "2026-07-14",
                "2026-07-14",
                "legacy-source-hash",
                3,
            ),
        )
        connection.commit()

    _upgrade(database_path, "head")

    with sqlite3.connect(database_path) as connection:
        assert connection.execute(
            """
            SELECT candidate_kind, period_start, source_hash,
                   eligible_signal_count
            FROM candidate_groups WHERE id = ?
            """,
            ("candidate-group-before-head",),
        ).fetchone() == (
            "micro_action",
            "2026-07-14",
            "legacy-source-hash",
            3,
        )
    assert metadata_schema_diffs(database_path) == []
    first_schema = sqlite_schema_fingerprint(database_path)
    _upgrade(database_path, "head")
    assert sqlite_schema_fingerprint(database_path) == first_schema


def test_real_raw_sql_006_database_reconciles_to_head_idempotently(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "raw-sql-006-to-head.sqlite"
    _upgrade(database_path, "0002_analytics")
    apply_real_legacy_sql_006(database_path)
    _seed_raw_sql_006_data(database_path)

    _upgrade(database_path, "head")

    assert current_revision(database_path) == head_revision()
    _assert_raw_sql_006_data_preserved(database_path)
    assert metadata_schema_diffs(database_path) == []
    first_schema = sqlite_schema_fingerprint(database_path)

    # `upgrade head` must be a true no-op after reconciliation. This protects
    # Railway restart/deploy retries from duplicate DDL or destructive rewrites.
    _upgrade(database_path, "head")

    assert sqlite_schema_fingerprint(database_path) == first_schema
    _assert_raw_sql_006_data_preserved(database_path)


def test_raw_sql_006_reconciles_uniqueness_and_preserves_fk_actions(
    tmp_path: Path,
) -> None:
    database_path = tmp_path / "raw-sql-006-constraints.sqlite"
    _upgrade(database_path, "0002_analytics")
    apply_real_legacy_sql_006(database_path)
    _seed_raw_sql_006_data(database_path)
    _seed_duplicate_raw_sql_usage_counters(database_path)

    _upgrade(database_path, "head")

    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")

        # Historical duplicate usage rows are merged before the authoritative
        # unique index is installed. Every additive counter must be preserved.
        merged_rows = connection.execute(
            """
            SELECT count, token_input, token_output, token_cached_input
            FROM usage_counters
            WHERE user_id = ? AND feature_key = ? AND period_type = ?
              AND period_start = ?
            """,
            (
                "sql-user",
                "migration_dedup_probe",
                "week",
                "2026-06-29",
            ),
        ).fetchall()
        assert merged_rows == [(7, 110, 55, 19)]
        assert _named_index(
            connection,
            "usage_counters",
            "uq_usage_counters_user_feature_period",
        ) == (
            True,
            ("user_id", "feature_key", "period_type", "period_start"),
        )
        assert _foreign_key_actions(connection, "usage_counters") == {
            ("user_id", "users", "id"): "CASCADE"
        }

        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                """
                INSERT INTO usage_counters(
                  id, user_id, feature_key, period_type, period_start
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    "duplicate-usage-after-head",
                    "sql-user",
                    "migration_dedup_probe",
                    "week",
                    "2026-06-29",
                ),
            )

        assert _named_index(
            connection,
            "signal_cards",
            "uq_signal_cards_user_client_id",
        ) == (True, ("user_id", "client_id"))
        assert _foreign_key_actions(connection, "signal_cards") == {
            ("capture_id", "captures", "id"): "SET NULL",
            ("raw_memory_id", "raw_memories", "id"): "SET NULL",
            ("user_id", "users", "id"): "CASCADE",
        }

        # Existing raw-SQL rows receive client_id=id during reconciliation.
        # A duplicate non-NULL client ID for the same user must be rejected.
        with pytest.raises(sqlite3.IntegrityError):
            _insert_signal(
                connection,
                signal_id="duplicate-client-id",
                client_id="sql-signal",
            )

        # SQLite and PostgreSQL unique indexes both permit multiple NULLs.
        _insert_signal(
            connection,
            signal_id="null-client-id-a",
            client_id=None,
        )
        _insert_signal(
            connection,
            signal_id="null-client-id-b",
            client_id=None,
        )
        assert connection.execute(
            """
            SELECT COUNT(*) FROM signal_cards
            WHERE user_id = ? AND client_id IS NULL
            """,
            ("sql-user",),
        ).fetchone() == (2,)

        # Exercise each signal parent relationship, not just reflected DDL.
        _insert_signal(
            connection,
            signal_id="signal-fk-probe",
            client_id="signal-fk-probe",
            capture_id="sql-capture",
            raw_memory_id="sql-memory",
        )
        connection.execute(
            "DELETE FROM captures WHERE id = ?", ("sql-capture",)
        )
        assert connection.execute(
            """
            SELECT capture_id, raw_memory_id FROM signal_cards WHERE id = ?
            """,
            ("signal-fk-probe",),
        ).fetchone() == (None, "sql-memory")

        connection.execute(
            "DELETE FROM raw_memories WHERE id = ?", ("sql-memory",)
        )
        assert connection.execute(
            """
            SELECT capture_id, raw_memory_id FROM signal_cards WHERE id = ?
            """,
            ("signal-fk-probe",),
        ).fetchone() == (None, None)

        connection.execute("DELETE FROM users WHERE id = ?", ("sql-user",))
        assert connection.execute(
            "SELECT COUNT(*) FROM usage_counters WHERE user_id = ?",
            ("sql-user",),
        ).fetchone() == (0,)
        assert connection.execute(
            "SELECT COUNT(*) FROM signal_cards WHERE user_id = ?",
            ("sql-user",),
        ).fetchone() == (0,)


def test_real_hybrid_raw_sql_006_through_019_reconciles_losslessly(
    tmp_path: Path,
) -> None:
    """Exercise the exact historic dual-source staging migration shape."""

    database_path = tmp_path / "hybrid-raw-sql-019-to-head.sqlite"
    _upgrade(database_path, "0002_analytics")
    apply_real_legacy_sql_006(database_path)
    _seed_raw_sql_006_data(database_path)
    _seed_weekly_before_legacy_backfill(database_path)
    apply_real_legacy_sql_range(database_path, 7, 19)
    _seed_legacy_019_sentinels(database_path)

    _upgrade(database_path, "head")

    assert current_revision(database_path) == head_revision()
    _assert_raw_sql_006_data_preserved(database_path)
    _assert_legacy_019_sentinels_preserved(database_path)
    assert metadata_schema_diffs(database_path) == []
    first_schema = sqlite_schema_fingerprint(database_path)

    _upgrade(database_path, "head")

    assert sqlite_schema_fingerprint(database_path) == first_schema
    _assert_legacy_019_sentinels_preserved(database_path)
