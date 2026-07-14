from __future__ import annotations

import json
import os
import re
import re
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any

from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import String, UniqueConstraint, create_engine


BACKEND_ROOT = Path(__file__).resolve().parents[1]
ALEMBIC_INI = BACKEND_ROOT / "alembic.ini"
LEGACY_SQL_ROOT = BACKEND_ROOT / "migrations"

SQLITE_DESC_INDEX_CONTRACT: dict[str, tuple[str, tuple[str, ...], str]] = {
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
        "pipeline_runs", ("status", "can_retry"), "updated_at"
    ),
    "idx_observations_user_status_date": (
        "observations", ("user_id", "status", "source_period_start"), "updated_at"
    ),
    "idx_life_experiment_events_exp": (
        "life_experiment_lifecycle_events", ("experiment_id",), "event_date"
    ),
    "idx_life_experiment_events_user_date": (
        "life_experiment_lifecycle_events", ("user_id",), "local_date"
    ),
    "idx_life_experiment_rollups_user_week": (
        "life_experiment_rollups", ("user_id",), "source_week_start"
    ),
    "idx_life_experiment_rollups_root": (
        "life_experiment_rollups", ("root_experiment_id",), "source_week_start"
    ),
    "idx_life_experiment_rollups_user_period": (
        "life_experiment_rollups",
        ("user_id", "source_week_start", "source_week_end"),
        "updated_at",
    ),
    "idx_trace_links_user_status": (
        "trace_links", ("user_id", "status"), "updated_at"
    ),
    "idx_candidate_groups_read": (
        "candidate_groups",
        ("user_id", "candidate_kind", "period_start", "status"),
        "updated_at",
    ),
}


def head_revision() -> str:
    config = Config(str(ALEMBIC_INI))
    config.set_main_option("script_location", str(BACKEND_ROOT / "alembic"))
    head = ScriptDirectory.from_config(config).get_current_head()
    assert head is not None
    assert len(head) <= 32, (
        "Alembic's default version_num column is VARCHAR(32); "
        f"revision {head!r} is too long"
    )
    return head


def run_alembic(
    database_path: Path,
    *arguments: str,
) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["DATABASE_URL"] = f"sqlite:///{database_path}"
    environment["PYTHONPATH"] = os.pathsep.join(
        value
        for value in (str(BACKEND_ROOT), environment.get("PYTHONPATH"))
        if value
    )
    return subprocess.run(
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
        timeout=60,
        check=False,
    )


def assert_alembic_succeeded(result: subprocess.CompletedProcess[str]) -> None:
    def redact(value: str) -> str:
        return re.sub(
            r"([a-z][a-z0-9+.-]*://[^:/\s]+:)[^@\s]+(@)",
            r"\1***\2",
            value,
            flags=re.IGNORECASE,
        )

    assert result.returncode == 0, (
        f"command: {' '.join(result.args)}\n"
        f"stdout:\n{redact(result.stdout)}\n"
        f"stderr:\n{redact(result.stderr)}"
    )


def current_revision(database_path: Path) -> str | None:
    with sqlite3.connect(database_path) as connection:
        exists = connection.execute(
            "SELECT 1 FROM sqlite_master "
            "WHERE type = 'table' AND name = 'alembic_version'"
        ).fetchone()
        if not exists:
            return None
        row = connection.execute(
            "SELECT version_num FROM alembic_version"
        ).fetchone()
        return None if row is None else str(row[0])


def sqlite_schema_fingerprint(database_path: Path) -> str:
    """Return a deterministic schema fingerprint, excluding SQLite internals."""

    with sqlite3.connect(database_path) as connection:
        objects = connection.execute(
            """
            SELECT type, name, tbl_name, COALESCE(sql, '')
            FROM sqlite_master
            WHERE name NOT LIKE 'sqlite_%'
            ORDER BY type, name, tbl_name
            """
        ).fetchall()
    return json.dumps(objects, ensure_ascii=False, separators=(",", ":"))


def metadata_schema_diffs(database_path: Path) -> list[Any]:
    """Return model-relevant Alembic autogenerate differences.

    Operational indexes and constraints are declared in ORM ``__table_args__``
    as part of the canonical schema, so the exact Alembic autogenerate diff
    must be empty.  This prevents either migration source from silently leaving
    stale tables, indexes, constraints, or columns behind.
    """

    # Imports are deliberately local.  Migration subprocesses receive their
    # own DATABASE_URL, while this process only needs the canonical metadata.
    from app.core.db import Base
    import app.models  # noqa: F401

    engine = create_engine(f"sqlite:///{database_path}", future=True)
    try:
        with engine.connect() as connection:
            context = MigrationContext.configure(
                connection,
                opts={
                    "compare_type": True,
                    # PostgreSQL and SQLite render equivalent defaults very
                    # differently; default behavior is covered by inserts.
                    "compare_server_default": False,
                },
            )
            raw_diffs = compare_metadata(context, Base.metadata)
            semantic_diffs = _filter_sqlite_semantic_equivalents(
                connection,
                Base.metadata,
                raw_diffs,
            )
    finally:
        engine.dispose()

    return semantic_diffs


def _filter_sqlite_semantic_equivalents(
    connection: Any,
    metadata: Any,
    diffs: list[Any],
) -> list[Any]:
    filtered: list[Any] = []
    for diff in diffs:
        if isinstance(diff, list):
            nested = _filter_sqlite_semantic_equivalents(
                connection,
                metadata,
                diff,
            )
            if nested:
                filtered.append(nested)
            continue
        if _is_sqlite_semantic_equivalent(connection, metadata, diff):
            continue
        filtered.append(diff)
    return filtered


def _is_sqlite_semantic_equivalent(
    connection: Any,
    metadata: Any,
    diff: Any,
) -> bool:
    if not isinstance(diff, tuple) or not diff:
        return False
    operation = diff[0]
    if operation in {"add_index", "remove_index"}:
        index = diff[1]
        contract = SQLITE_DESC_INDEX_CONTRACT.get(str(index.name))
        if contract is not None:
            table_name, prefix, descending_column = contract
            return (
                index.table.name == table_name
                and _sqlite_index_column_ordering(connection, str(index.name))
                == tuple((name, False) for name in prefix)
                + ((descending_column, True),)
            )
    if operation == "modify_type":
        existing_type, model_type = diff[-2:]
        return existing_type._type_affinity is model_type._type_affinity
    if operation == "modify_nullable":
        _, _, table_name, column_name, _, existing, expected = diff
        model_column = metadata.tables[table_name].c[column_name]
        return (
            existing is True
            and expected is False
            and model_column.primary_key
            and model_column.type._type_affinity is String
            and column_name in _sqlite_primary_key_columns(
                connection,
                table_name,
            )
        )
    if operation in {"add_fk", "remove_fk"}:
        constraint = diff[1]
        table_name = constraint.table.name
        return _sqlite_foreign_key_signatures(
            connection,
            table_name,
        ) == _metadata_foreign_key_signatures(metadata.tables[table_name])
    if operation == "add_constraint" and isinstance(
        diff[1], UniqueConstraint
    ):
        constraint = diff[1]
        columns = tuple(column.name for column in constraint.columns)
        return columns in _sqlite_unique_index_columns(
            connection,
            constraint.table.name,
        )
    if operation == "remove_index":
        index = diff[1]
        columns = tuple(column.name for column in index.columns)
        model_uniques = {
            tuple(column.name for column in constraint.columns)
            for constraint in metadata.tables[index.table.name].constraints
            if isinstance(constraint, UniqueConstraint)
        }
        model_unique_indexes = {
            tuple(column.name for column in candidate.columns)
            for candidate in metadata.tables[index.table.name].indexes
            if candidate.unique
        }
        return bool(index.unique) and columns in (
            model_uniques | model_unique_indexes
        )
    return False


def _sqlite_index_column_ordering(
    connection: Any,
    index_name: str,
) -> tuple[tuple[str, bool], ...]:
    escaped_name = index_name.replace('"', '""')
    rows = connection.exec_driver_sql(
        f'PRAGMA index_xinfo("{escaped_name}")'
    ).mappings()
    return tuple(
        (str(row["name"]), bool(row["desc"]))
        for row in rows
        if bool(row["key"])
    )


def _sqlite_primary_key_columns(
    connection: Any,
    table_name: str,
) -> set[str]:
    rows = connection.exec_driver_sql(
        f'PRAGMA table_info("{table_name}")'
    ).mappings()
    return {str(row["name"]) for row in rows if int(row["pk"] or 0) > 0}


def _sqlite_unique_index_columns(
    connection: Any,
    table_name: str,
) -> set[tuple[str, ...]]:
    signatures: set[tuple[str, ...]] = set()
    indexes = connection.exec_driver_sql(
        f'PRAGMA index_list("{table_name}")'
    ).mappings()
    for index in indexes:
        if not bool(index["unique"]):
            continue
        index_name = str(index["name"]).replace('"', '""')
        columns = connection.exec_driver_sql(
            f'PRAGMA index_info("{index_name}")'
        ).mappings()
        signatures.add(tuple(str(column["name"]) for column in columns))
    return signatures


def _sqlite_foreign_key_signatures(
    connection: Any,
    table_name: str,
) -> set[tuple[tuple[str, ...], str, tuple[str, ...], str]]:
    grouped: dict[int, list[Any]] = {}
    rows = connection.exec_driver_sql(
        f'PRAGMA foreign_key_list("{table_name}")'
    ).mappings()
    for row in rows:
        grouped.setdefault(int(row["id"]), []).append(row)

    signatures: set[tuple[tuple[str, ...], str, tuple[str, ...], str]] = set()
    for parts in grouped.values():
        ordered = sorted(parts, key=lambda item: int(item["seq"]))
        signatures.add(
            (
                tuple(str(item["from"]) for item in ordered),
                str(ordered[0]["table"]),
                tuple(str(item["to"]) for item in ordered),
                str(ordered[0]["on_delete"] or "NO ACTION").upper(),
            )
        )
    return signatures


def _metadata_foreign_key_signatures(
    table: Any,
) -> set[tuple[tuple[str, ...], str, tuple[str, ...], str]]:
    return {
        (
            tuple(element.parent.name for element in constraint.elements),
            constraint.elements[0].column.table.name,
            tuple(element.column.name for element in constraint.elements),
            str(constraint.ondelete or "NO ACTION").upper(),
        )
        for constraint in table.foreign_key_constraints
    }


def apply_real_legacy_sql_006(database_path: Path) -> None:
    """Apply the independently deployed SignalCard SQL to Alembic 0002.

    Staging historically combined the Alembic base/analytics schema with the
    standalone 006+ SQL files.  Tests execute the real 006 DDL on SQLite after
    a deliberately tiny type/default normalization; table, column, constraint,
    and index declarations remain sourced from the actual migration rather
    than a hand-maintained fake schema.
    """

    apply_real_legacy_sql_range(database_path, 6, 6)


def apply_real_legacy_sql_range(
    database_path: Path,
    first: int,
    last: int,
) -> None:
    scripts_by_number = {
        int(path.name[:3]): path
        for path in LEGACY_SQL_ROOT.glob("[0-9][0-9][0-9]_*.sql")
    }
    missing = set(range(first, last + 1)) - scripts_by_number.keys()
    assert not missing, f"missing legacy SQL migrations: {sorted(missing)}"

    with sqlite3.connect(database_path) as connection:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.create_function(
            "jsonb_build_object",
            -1,
            _sqlite_json_object,
        )
        for number in range(first, last + 1):
            sql = _postgres_sql_for_sqlite(
                scripts_by_number[number].read_text()
            )
            connection.executescript(sql)


def _sqlite_json_object(*items: Any) -> str:
    assert len(items) % 2 == 0
    return json.dumps(
        dict(zip(items[::2], items[1::2], strict=True)),
        ensure_ascii=False,
    )


def _postgres_sql_for_sqlite(sql: str) -> str:
    normalized = re.sub(r"::jsonb\b", "", sql, flags=re.IGNORECASE)
    normalized = re.sub(
        r"\b([A-Za-z_][A-Za-z0-9_]*)::text\b",
        r"CAST(\1 AS TEXT)",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"\btimestamptz\b", "DATETIME", normalized, flags=re.IGNORECASE)
    normalized = re.sub(
        r"\btimestamp\s+with\s+time\s+zone\b",
        "DATETIME",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"\bjsonb\b", "JSON", normalized, flags=re.IGNORECASE)
    normalized = re.sub(
        r"\bdouble\s+precision\b", "FLOAT", normalized, flags=re.IGNORECASE
    )
    normalized = re.sub(r"\bnow\(\)", "CURRENT_TIMESTAMP", normalized, flags=re.IGNORECASE)
    # SQLAlchemy's SQLite reflection recovers ON DELETE options by parsing the
    # original CREATE TABLE text and expects canonical keyword casing. Keep the
    # PostgreSQL semantics visible so batch reconciliation does not downgrade
    # CASCADE / SET NULL to NO ACTION in the test dialect.
    normalized = re.sub(
        r"\bon\s+delete\s+cascade\b",
        "ON DELETE CASCADE",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(
        r"\bon\s+delete\s+set\s+null\b",
        "ON DELETE SET NULL",
        normalized,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(
        r"\bADD\s+COLUMN\s+IF\s+NOT\s+EXISTS\b",
        "ADD COLUMN",
        normalized,
        flags=re.IGNORECASE,
    )
    # SQLite needs a WHERE clause to disambiguate UPSERT after INSERT..SELECT.
    normalized = re.sub(
        r"(FROM\s+[A-Za-z_][A-Za-z0-9_]*)\s+(ON\s+CONFLICT)",
        r"\1 WHERE true\n\2",
        normalized,
        flags=re.IGNORECASE,
    )
    return normalized
