# Authoritative database migrations

Alembic is the only supported schema migration mechanism for SignalPath.

- New databases must run `alembic upgrade head` before the API starts.
- Existing databases must upgrade through the same command.
- Application startup does not call `Base.metadata.create_all()`.
- `backend/migrations/*.sql` is read-only legacy evidence used only by tests.
- Every schema change requires a new revision plus fresh/legacy-to-head schema
  contract coverage.

Revision `0007_schema_reconcile` is the one-time bridge that adopts the known
historical Alembic + SQL hybrid shapes without dropping user data.
Revision `0008_postgres_canonical` makes the PostgreSQL physical
schema exact after that bridge: JSONB, the historical unbounded TEXT columns,
named constraints, partial identity uniqueness, and descending query indexes.

CI also replays the unmodified SQL `006`-`019` chain inside a unique temporary
PostgreSQL schema and requires an empty Alembic metadata diff at `head`. To run
that contract locally, set `POSTGRES_MIGRATION_TEST_URL` to a disposable
PostgreSQL database. `DATABASE_URL` is considered only when
`POSTGRES_MIGRATION_TEST_USE_DATABASE_URL=1` is explicitly set; the test still
creates and drops only its uniquely named schema.

The adoption/reconciliation chain is forward-only. Do not run downgrade across
`0003`–`0008`: a legacy table may have existed before Alembic adopted it, so a
downgrade cannot safely know which objects it owns. Operational rollback means
restoring a verified database backup and deploying compatible application code.
