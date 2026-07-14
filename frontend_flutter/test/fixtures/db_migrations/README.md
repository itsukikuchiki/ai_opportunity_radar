# DB Migration Fixtures

These SQLite fixtures support P2.1 migration and legacy compatibility tests.
They are schema-compatible fixtures: each file is created with the current
local schema, seeded with legacy-shaped data, then its `PRAGMA user_version`
is set back to the target source version so upgrade paths can be exercised.

Regenerate from `frontend_flutter` with:

```sh
flutter test test/fixtures/db_migrations/build_db_migration_fixtures.dart
```

Run the verification test after regenerating:

```sh
flutter test test/core/local/db_migration_fixtures_test.dart
```

## Fixture Index

| File | user_version | Purpose |
| --- | ---: | --- |
| `fresh_user_v30.db` | 30 | Empty v30 user DB for forward upgrade smoke tests. |
| `legacy_v27_captures.db` | 27 | Legacy `captures` row with AI mirror fields. |
| `legacy_v28_snapshot_ai_fields.db` | 28 | Weekly snapshot with legacy AI mirror content and no `reflection_results`. |
| `legacy_v29_life_experiment_embedded.db` | 29 | Weekly snapshot containing legacy `opportunity_snapshot_json._life_experiment`. |
| `legacy_signal_mirror_fields.db` | 29 | SignalCard mirror fields without split processing or analysis-policy rows. |
| `legacy_no_trace_data.db` | 30 | Valid legacy data with no `trace_links`, for empty/fallback evidence behavior. |
| `large_user_2000_signals.db` | 32 | Large local account fixture with 2,000 SignalCards. |
| `deleted_signal_with_trace.db` | 32 | Deleted SignalCard with inactive trace and active tombstone. |
| `old_prompt_version.db` | 32 | Weekly reflection generated with old prompt/model versions. |
