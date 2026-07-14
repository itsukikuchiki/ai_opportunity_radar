# P2.1-17 Device Test Accounts

This directory contains generated SQLite databases for real-device and manual
QA preparation.

Regenerate:

```sh
cd frontend_flutter
flutter test test/fixtures/device_accounts/build_device_test_accounts.dart
flutter test test/core/local/device_test_accounts_fixture_test.dart
```

Generated files:

| Account | DB file | Purpose |
| --- | --- | --- |
| `fresh_user` | `fresh_user.db` | Empty current-schema user. No legacy fallback should fire. |
| `legacy_user` | `legacy_user.db` | Compatibility user with old captures, weekly mirrors, embedded `_life_experiment`, old DeepWeekly result, old feedback, SignalCard mirrors, and Journey data without `trace_links`. |
| `heavy_user` | `heavy_user.db` | 2,000 SignalCards for period-query and UI load smoke tests. |
| `offline_user` | `offline_user.db` | Local draft, stable `client_id`, and `sync_failed` retry scenarios. |
| `experiment_user` | `experiment_user.db` | Candidate -> Life Experiment -> feedback -> rollup -> Journey evidence chain. |
| `privacy_user` | `privacy_user.db` | Privacy excluded, inaccurate, deleted, inactive trace, and stale propagation cases. |

`manifest.json` is regenerated with the DB list and account highlights. Import
one fixture into a booted Simulator with:

```sh
tool/import_device_fixture.sh fresh_user
```

The safe Simulator and physical-device workflows, backup behavior, and
`devicectl` limitation are documented in
`docs/active/device_test_accounts.md`.
