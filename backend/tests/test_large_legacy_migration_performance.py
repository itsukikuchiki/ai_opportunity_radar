from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import date, datetime, time, timedelta
from pathlib import Path
from time import perf_counter
from typing import Callable, TypeVar

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.repositories.capture_repository import CaptureRepository
from app.repositories.memory_repository import MemoryRepository
from tests._migration_test_support import (
    apply_real_legacy_sql_006,
    apply_real_legacy_sql_range,
    assert_alembic_succeeded,
    current_revision,
    head_revision,
    metadata_schema_diffs,
    run_alembic,
)


SIGNAL_COUNT = 2_000
USER_ID = "large-legacy-user"
FIRST_LOCAL_DATE = date(2026, 6, 15)
WEEK_START = date(2026, 6, 29)
WEEK_END = date(2026, 7, 5)

# These are deliberately soft regression limits, not benchmark targets.  A
# normal developer Mac completes each read in well under a second.  The wide
# margin keeps shared GitHub runners stable while still catching accidental
# unbounded retries, per-row network work, or a severe N^2 regression.
MIGRATION_SOFT_LIMIT_SECONDS = 30.0
TODAY_READ_SOFT_LIMIT_SECONDS = 12.0
WEEKLY_READ_SOFT_LIMIT_SECONDS = 8.0
JOURNEY_READ_SOFT_LIMIT_SECONDS = 8.0


T = TypeVar("T")


def _timed(call: Callable[[], T]) -> tuple[T, float]:
    started_at = perf_counter()
    result = call()
    return result, perf_counter() - started_at


def _assert_soft_limit(
    *,
    operation: str,
    elapsed_seconds: float,
    limit_seconds: float,
) -> None:
    assert elapsed_seconds < limit_seconds, (
        f"{operation} took {elapsed_seconds:.3f}s for {SIGNAL_COUNT:,} "
        f"legacy SignalCards; soft limit is {limit_seconds:.1f}s"
    )


def _signal_rows() -> list[tuple[object, ...]]:
    rows: list[tuple[object, ...]] = []
    scenes = ("work", "relationship", "recovery")
    frictions = ("execution", "coordination", "emotional")
    sources = ("text", "voice", "status")

    for ordinal in range(SIGNAL_COUNT):
        local_date = FIRST_LOCAL_DATE + timedelta(days=ordinal % 28)
        created_at = datetime.combine(local_date, time(hour=8)) + timedelta(
            seconds=ordinal
        )
        rows.append(
            (
                f"legacy-signal-{ordinal:04d}",
                USER_ID,
                sources[ordinal % len(sources)],
                f"legacy raw text {ordinal:04d}",
                json.dumps({"ordinal": ordinal}, separators=(",", ":")),
                created_at.isoformat(sep=" "),
                local_date.isoformat(),
                "Asia/Tokyo",
                "zh-Hans",
                "calm" if ordinal % 2 == 0 else "tired",
                (ordinal % 5) + 1,
                scenes[ordinal % len(scenes)],
                frictions[ordinal % len(frictions)],
                "low" if ordinal % 3 == 0 else "medium",
                "confirmed",
                1,
                1,
                1,
                "private",
                json.dumps(
                    {"fixture": "real_raw_sql_006", "ordinal": ordinal},
                    separators=(",", ":"),
                ),
            )
        )
    return rows


def _content_digest(rows: list[tuple[str, str, str]]) -> str:
    digest = hashlib.sha256()
    for signal_id, raw_text, local_date in rows:
        digest.update(signal_id.encode())
        digest.update(b"\x1f")
        digest.update(raw_text.encode())
        digest.update(b"\x1f")
        digest.update(local_date.encode())
        digest.update(b"\n")
    return digest.hexdigest()


def _build_real_hybrid_legacy_database(
    database_path: Path,
) -> tuple[str, int, list[str]]:
    """Build the deployed 0002 + real raw SQL 006-019 database shape.

    This intentionally does not call current ``Base.metadata.create_all``.
    The 2,000 facts are inserted while ``signal_cards`` still has the exact
    standalone 006 schema, before the historical 007-019 backfills run.
    """

    base_upgrade = run_alembic(database_path, "upgrade", "0002_analytics")
    assert_alembic_succeeded(base_upgrade)
    apply_real_legacy_sql_006(database_path)

    signal_rows = _signal_rows()
    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("INSERT INTO users(id) VALUES (?)", (USER_ID,))
        connection.executemany(
            """
            INSERT INTO signal_cards(
              id, user_id, source_type, raw_text, raw_payload_json,
              created_at, local_date, timezone, language, emotion, intensity,
              scene, friction, energy_load, user_confirmation,
              included_in_summary, included_in_weekly, included_in_journey,
              privacy_level, metadata_json
            ) VALUES (
              ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
            )
            """,
            signal_rows,
        )
        connection.commit()

    # Apply the actual independently deployed files rather than recreating
    # their schema in a test helper.  007 backfills split state/policy for all
    # 2,000 rows, while 010 backfills client/server identity.
    apply_real_legacy_sql_range(database_path, 7, 19)

    with sqlite3.connect(database_path) as connection:
        persisted_rows = connection.execute(
            """
            SELECT id, raw_text, local_date
            FROM signal_cards
            ORDER BY id
            """
        ).fetchall()

    expected_weekly_count = sum(
        WEEK_START.isoformat() <= str(row[6]) <= WEEK_END.isoformat()
        for row in signal_rows
    )
    expected_recent_ids = [
        str(row[0])
        for row in sorted(signal_rows, key=lambda row: str(row[5]), reverse=True)[:200]
    ]
    return _content_digest(persisted_rows), expected_weekly_count, expected_recent_ids


def _assert_large_data_integrity(
    database_path: Path,
    *,
    expected_digest: str,
) -> None:
    with sqlite3.connect(database_path) as connection:
        rows = connection.execute(
            """
            SELECT id, raw_text, local_date
            FROM signal_cards
            WHERE user_id = ?
            ORDER BY id
            """,
            (USER_ID,),
        ).fetchall()
        assert len(rows) == SIGNAL_COUNT
        assert _content_digest(rows) == expected_digest
        assert connection.execute(
            """
            SELECT COUNT(*), COUNT(DISTINCT client_id), COUNT(DISTINCT server_id)
            FROM signal_cards WHERE user_id = ?
            """,
            (USER_ID,),
        ).fetchone() == (SIGNAL_COUNT, SIGNAL_COUNT, SIGNAL_COUNT)
        assert connection.execute(
            """
            SELECT COUNT(*) FROM signal_processing_state
            WHERE signal_id LIKE 'legacy-signal-%'
            """
        ).fetchone() == (SIGNAL_COUNT,)
        assert connection.execute(
            """
            SELECT COUNT(*) FROM signal_analysis_policy
            WHERE signal_id LIKE 'legacy-signal-%'
            """
        ).fetchone() == (SIGNAL_COUNT,)
        assert connection.execute(
            """
            SELECT COUNT(*) FROM signal_cards
            WHERE user_id = ? AND deleted_at IS NOT NULL
            """,
            (USER_ID,),
        ).fetchone() == (0,)


def test_real_hybrid_legacy_database_with_2000_signals_upgrades_and_reads(
    tmp_path: Path,
    record_property: Callable[[str, object], None],
) -> None:
    database_path = tmp_path / "large-real-hybrid-legacy.sqlite"
    expected_digest, expected_weekly_count, expected_recent_ids = (
        _build_real_hybrid_legacy_database(database_path)
    )

    upgrade_result, migration_seconds = _timed(
        lambda: run_alembic(database_path, "upgrade", "head")
    )
    assert_alembic_succeeded(upgrade_result)
    record_property("legacy_signal_count", SIGNAL_COUNT)
    record_property("migration_seconds", round(migration_seconds, 6))
    _assert_soft_limit(
        operation="hybrid legacy database -> Alembic head migration",
        elapsed_seconds=migration_seconds,
        limit_seconds=MIGRATION_SOFT_LIMIT_SECONDS,
    )

    assert current_revision(database_path) == head_revision()
    assert metadata_schema_diffs(database_path) == []
    _assert_large_data_integrity(
        database_path,
        expected_digest=expected_digest,
    )

    engine = create_engine(f"sqlite:///{database_path}", future=True)
    try:
        with Session(engine) as session:
            recent_cards, today_seconds = _timed(
                lambda: CaptureRepository(session).list_recent_signal_cards(
                    USER_ID,
                    limit=200,
                )
            )
            assert [card.id for card in recent_cards] == expected_recent_ids
        record_property("today_repository_seconds", round(today_seconds, 6))
        _assert_soft_limit(
            operation="Today recent SignalCard repository read",
            elapsed_seconds=today_seconds,
            limit_seconds=TODAY_READ_SOFT_LIMIT_SECONDS,
        )

        with Session(engine) as session:
            weekly_summary, weekly_seconds = _timed(
                lambda: MemoryRepository(session).raw_summary(
                    USER_ID,
                    WEEK_START,
                    WEEK_END,
                )
            )
            assert weekly_summary["signal_count"] == expected_weekly_count
            assert set(weekly_summary["top_scene_types"]) == {
                "work",
                "relationship",
                "recovery",
            }
            assert set(weekly_summary["top_friction_types"]) == {
                "execution",
                "coordination",
                "emotional",
            }
        record_property("weekly_repository_seconds", round(weekly_seconds, 6))
        _assert_soft_limit(
            operation="Weekly period SignalCard repository read",
            elapsed_seconds=weekly_seconds,
            limit_seconds=WEEKLY_READ_SOFT_LIMIT_SECONDS,
        )

        with Session(engine) as session:
            first_signal_date, journey_seconds = _timed(
                lambda: MemoryRepository(session).get_first_signal_date(USER_ID)
            )
            assert first_signal_date == FIRST_LOCAL_DATE
        record_property("journey_repository_seconds", round(journey_seconds, 6))
        _assert_soft_limit(
            operation="Journey first-evidence repository read",
            elapsed_seconds=journey_seconds,
            limit_seconds=JOURNEY_READ_SOFT_LIMIT_SECONDS,
        )
    finally:
        engine.dispose()
