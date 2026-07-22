"""add explicit candidate decision status

Revision ID: 0009_candidate_decisions
Revises: 0008_postgres_canonical
Create Date: 2026-07-17
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "0009_candidate_decisions"
down_revision = "0008_postgres_canonical"
branch_labels = None
depends_on = None


DECISION_STATUS_CHECK = (
    "decision_status IN ('undecided', 'considering', 'adopted')"
)


def _add_decision_status(table_name: str, constraint_name: str) -> None:
    # Keep this as an inline column check.  A SQLite batch-table rebuild can
    # lose ON DELETE options while reflecting historic inline foreign keys.
    op.add_column(
        table_name,
        sa.Column(
            "decision_status",
            sa.String(),
            sa.CheckConstraint(
                DECISION_STATUS_CHECK,
                name=constraint_name,
            ),
            nullable=False,
            server_default="undecided",
        )
    )


def _backfill_decision_status(
    table_name: str,
    adopted_id_column: str,
) -> None:
    table = sa.table(
        table_name,
        sa.column("decision_status", sa.String()),
        sa.column("status", sa.String()),
        sa.column(adopted_id_column, sa.String()),
    )
    normalized_status = sa.func.lower(sa.func.trim(table.c.status))
    adopted_id = table.c[adopted_id_column]
    has_adopted_id = sa.and_(
        adopted_id.is_not(None),
        sa.func.trim(adopted_id) != "",
    )
    op.execute(
        table.update().values(
            decision_status=sa.case(
                (
                    sa.or_(
                        has_adopted_id,
                        normalized_status.in_(("adopted", "planned", "active")),
                    ),
                    "adopted",
                ),
                (
                    normalized_status.in_(
                        ("considering", "observing", "reviewing", "saved")
                    ),
                    "considering",
                ),
                else_="undecided",
            )
        )
    )


def upgrade() -> None:
    _add_decision_status(
        "micro_action_candidates",
        "ck_micro_action_candidates_decision_status",
    )
    _add_decision_status(
        "experiment_candidates",
        "ck_experiment_candidates_decision_status",
    )
    _backfill_decision_status(
        "micro_action_candidates",
        "adopted_micro_action_id",
    )
    _backfill_decision_status(
        "experiment_candidates",
        "adopted_experiment_id",
    )


def downgrade() -> None:
    op.drop_column("experiment_candidates", "decision_status")
    op.drop_column("micro_action_candidates", "decision_status")
