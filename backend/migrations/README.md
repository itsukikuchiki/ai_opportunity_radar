# Retired SQL migrations

The numbered SQL files in this directory are retained only as immutable
historical fixtures for validating upgrades from databases that used the old
dual migration system.

They are **not an executable migration source**. Do not apply them to new or
existing environments. Alembic under `backend/alembic/` is the sole schema
authority; use:

```bash
cd backend
python -m alembic -c alembic.ini upgrade head
```

Migration contract tests deliberately replay selected SQL files into temporary
legacy databases, then prove that the Alembic reconciliation revision preserves
their data and reaches the current schema.

This historical adoption path is forward-only. Never use Alembic downgrade to
remove an object that may have been created by these SQL files; restore a
verified database backup instead.
