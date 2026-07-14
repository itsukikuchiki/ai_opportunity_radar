from __future__ import annotations

import sqlite3
from pathlib import Path

import pytest

from tests._migration_test_support import (
    assert_alembic_succeeded,
    head_revision,
    run_alembic,
)


def _create_0005_database(
    database_path: Path,
    *,
    with_experiment_candidates: bool,
) -> None:
    # Build the starting point through the real Alembic chain. A hand-written
    # stamped database can accidentally omit base tables and prove only that a
    # fake schema upgrades, not that a deployed 0005 database does.
    assert_alembic_succeeded(
        run_alembic(
            database_path,
            "upgrade",
            "0005_legacy_endpoint_telemetry",
        )
    )
    with sqlite3.connect(database_path) as connection:
        connection.execute(
            "INSERT INTO users(id) VALUES (?)",
            ("migration-user",),
        )
        connection.commit()

        if not with_experiment_candidates:
            return

        # This is the established pre-candidate-planning table. It deliberately
        # omits both the 017 invalidation columns and the 019 planning columns,
        # exercising the oldest deployed shape that 0006 must accept.
        connection.executescript(
            """
            CREATE TABLE experiment_candidates (
              id TEXT PRIMARY KEY,
              user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
              source_type TEXT NOT NULL,
              source_id TEXT NOT NULL,
              source_week_start DATE NOT NULL,
              source_week_end DATE NOT NULL,
              title TEXT NOT NULL,
              hypothesis TEXT NOT NULL,
              suggested_action TEXT NOT NULL,
              linked_signal_card_ids JSON NOT NULL DEFAULT '[]',
              linked_observation_ids JSON NOT NULL DEFAULT '[]',
              status TEXT NOT NULL DEFAULT 'generated',
              confidence_level TEXT NOT NULL DEFAULT 'medium',
              metadata_json JSON NOT NULL DEFAULT '{}',
              adopted_experiment_id TEXT,
              created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
              updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
            );

            CREATE INDEX idx_experiment_candidates_source
              ON experiment_candidates(source_type, source_id, user_id);
            CREATE INDEX idx_experiment_candidates_week
              ON experiment_candidates(user_id, source_week_start, status);
            CREATE INDEX idx_experiment_candidates_adopted
              ON experiment_candidates(adopted_experiment_id);

            INSERT INTO experiment_candidates (
              id,
              user_id,
              source_type,
              source_id,
              source_week_start,
              source_week_end,
              title,
              hypothesis,
              suggested_action
            ) VALUES (
              'existing-candidate',
              'migration-user',
              'weekly_reflection',
              'weekly-1',
              '2026-07-06',
              '2026-07-12',
              'Preserve me',
              'Existing data survives',
              'Run the migration'
            );
            """
        )


def _upgrade_head(database_path: Path):
    return run_alembic(database_path, "upgrade", "head")


def _column_names(connection: sqlite3.Connection, table_name: str) -> set[str]:
    return {
        row[1]
        for row in connection.execute(f'PRAGMA table_info("{table_name}")')
    }


def _index_columns(
    connection: sqlite3.Connection,
    table_name: str,
) -> dict[str, tuple[str, ...]]:
    indexes: dict[str, tuple[str, ...]] = {}
    for row in connection.execute(f'PRAGMA index_list("{table_name}")'):
        index_name = row[1]
        indexes[index_name] = tuple(
            info[2]
            for info in connection.execute(f'PRAGMA index_info("{index_name}")')
        )
    return indexes


@pytest.mark.parametrize(
    "with_experiment_candidates",
    [False, True],
    ids=["alembic-only-0005", "existing-experiment-candidates"],
)
def test_upgrade_head_from_0005_creates_candidate_planning_schema(
    tmp_path: Path,
    with_experiment_candidates: bool,
) -> None:
    database_path = tmp_path / "candidate-planning.db"
    _create_0005_database(
        database_path,
        with_experiment_candidates=with_experiment_candidates,
    )

    first_upgrade = _upgrade_head(database_path)
    assert first_upgrade.returncode == 0, (
        f"stdout:\n{first_upgrade.stdout}\n"
        f"stderr:\n{first_upgrade.stderr}"
    )

    # A second upgrade is a real Alembic no-op and proves the head is stable.
    second_upgrade = _upgrade_head(database_path)
    assert second_upgrade.returncode == 0, (
        f"stdout:\n{second_upgrade.stdout}\n"
        f"stderr:\n{second_upgrade.stderr}"
    )

    with sqlite3.connect(database_path) as connection:
        version = connection.execute(
            "SELECT version_num FROM alembic_version"
        ).fetchone()
        assert version == (head_revision(),)

        tables = {
            row[0]
            for row in connection.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        assert {
            "candidate_groups",
            "micro_action_candidates",
            "experiment_candidates",
        }.issubset(tables)

        assert {
            "candidate_kind",
            "period_start",
            "period_end",
            "source_hash",
            "required_signal_count",
            "eligible_signal_count",
            "is_stale",
        }.issubset(_column_names(connection, "candidate_groups"))
        assert {
            "candidate_group_id",
            "local_date",
            "rank",
            "linked_signal_card_ids",
            "adopted_micro_action_id",
            "source_hash",
            "is_stale",
        }.issubset(_column_names(connection, "micro_action_candidates"))
        assert {
            "dirty",
            "is_stale",
            "stale_reason",
            "invalidated_at",
            "candidate_group_id",
            "candidate_rank",
            "source_hash",
        }.issubset(_column_names(connection, "experiment_candidates"))

        assert _index_columns(connection, "candidate_groups")[
            "idx_candidate_groups_read"
        ] == (
            "user_id",
            "candidate_kind",
            "period_start",
            "status",
            "updated_at",
        )
        micro_indexes = _index_columns(connection, "micro_action_candidates")
        assert micro_indexes["idx_micro_action_candidates_group"] == (
            "candidate_group_id",
            "rank",
        )
        assert micro_indexes["idx_micro_action_candidates_read"] == (
            "user_id",
            "local_date",
            "status",
            "dirty",
            "is_stale",
            "rank",
        )

        experiment_indexes = _index_columns(connection, "experiment_candidates")
        assert experiment_indexes["idx_experiment_candidates_group"] == (
            "candidate_group_id",
            "candidate_rank",
        )
        assert experiment_indexes["idx_experiment_candidates_stale"] == (
            "user_id",
            "source_week_start",
            "dirty",
            "is_stale",
            "status",
        )
        assert experiment_indexes["idx_experiment_candidates_source"] == (
            "source_type",
            "source_id",
            "user_id",
        )

        if with_experiment_candidates:
            preserved = connection.execute(
                """
                SELECT title, candidate_rank, dirty, is_stale
                FROM experiment_candidates
                WHERE id = 'existing-candidate'
                """
            ).fetchone()
            assert preserved == ("Preserve me", 1, 0, 0)

        connection.execute(
            """
            INSERT INTO candidate_groups (
              id, user_id, candidate_kind, period_start, period_end, source_hash
            ) VALUES (
              'group-1', 'migration-user', 'micro_action',
              '2026-07-13', '2026-07-13', 'stable-source'
            )
            """
        )
        connection.commit()

        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                """
                INSERT INTO candidate_groups (
                  id, user_id, candidate_kind, period_start, period_end, source_hash
                ) VALUES (
                  'group-duplicate', 'migration-user', 'micro_action',
                  '2026-07-13', '2026-07-13', 'stable-source'
                )
                """
            )
        connection.rollback()

        with pytest.raises(sqlite3.IntegrityError):
            connection.execute(
                """
                INSERT INTO micro_action_candidates (
                  id, candidate_group_id, user_id, local_date, rank,
                  title, source_hash
                ) VALUES (
                  'micro-rank-4', 'group-1', 'migration-user', '2026-07-13', 4,
                  'must fail', 'stable-source'
                )
                """
            )
        connection.rollback()
