# P2.1-17 Test Accounts And Data

Status: prepared for real-device testing.

Fixture source:

- Generator: `frontend_flutter/test/fixtures/device_accounts/build_device_test_accounts.dart`
- Output: `frontend_flutter/test/fixtures/device_accounts/*.db`
- Manifest: `frontend_flutter/test/fixtures/device_accounts/manifest.json`
- Guard test: `frontend_flutter/test/core/local/device_test_accounts_fixture_test.dart`

Regenerate and verify:

```sh
cd frontend_flutter
flutter test test/fixtures/device_accounts/build_device_test_accounts.dart
flutter test test/core/local/device_test_accounts_fixture_test.dart
```

## Accounts

| Account | Main use | Must verify |
| --- | --- | --- |
| `fresh_user` | Fresh install / new schema baseline | No stale legacy fallback, empty Today / Weekly / Journey states behave cleanly. |
| `legacy_user` | Legacy compatibility | Old captures, old weekly snapshot, embedded `_life_experiment`, old DeepWeekly result, old life experiment feedback, snapshot AI mirror, SignalCard mirror fields, and missing Journey trace data are all present. |
| `heavy_user` | Performance and period filtering | Weekly / Journey read by period and do not full-scan all 2,000 signals in UI paths. |
| `offline_user` | Offline input and retry identity | Draft has stable `client_id`; retry does not duplicate SignalCard; `sync_failed` is excluded from high-level analysis. |
| `experiment_user` | Main value chain | `experiment_candidates` -> `life_experiments` -> lifecycle -> feedback -> rollup -> Journey evidence works. |
| `privacy_user` | Delete / privacy / stale propagation | Excluded, `do_not_analyze`, inaccurate, and deleted data do not appear as active evidence; stale rows are visible in debug. |

## Legacy Samples

| Required sample | Fixture coverage |
| --- | --- |
| Old captures | `legacy_user.db`, table `captures`, row `cap_legacy_001` |
| Old weekly snapshot | `legacy_user.db`, table `weekly_snapshots`, week `2026-06-01` |
| Old `_life_experiment` | `legacy_user.db`, `weekly_snapshots.opportunity_snapshot_json._life_experiment` |
| Old DeepWeekly result | `legacy_user.db`, `reflection_results.refl_legacy_deep_weekly_001` |
| Old life experiment feedback | `legacy_user.db`, `life_experiment_feedback.lef_legacy_001` |
| Old snapshot AI mirror | `legacy_user.db`, `captures.ai_*` and `weekly_snapshots.opportunity_snapshot_json.legacy_ai_summary` |
| Old SignalCard mirror fields | `legacy_user.db`, `signal_cards.sig_legacy_mirror_001` without split processing / policy rows |
| Journey data missing trace | `legacy_user.db`, `journey_snapshots.2026-06` with empty `trace_links` |

## Notes

`FeedbackEvent` is not a standalone table in the current local data model. It is
the active unified read view over `micro_action_feedback` and
`life_experiment_feedback`. Schedule/Goal rows may exist only in the
`legacy_user` compatibility fixture so tests can prove that they are decoded
for migration/deletion but excluded from active Weekly/Journey feedback reads.
The `experiment_user` fixture verifies only the two active feedback grains.

## One-command import

The importer always replaces the single active local database, so import one
account at a time and finish that account's QA pass before switching:

```sh
cd frontend_flutter
tool/import_device_fixture.sh --list
tool/import_device_fixture.sh fresh_user
tool/import_device_fixture.sh legacy_user --simulator booted --launch
tool/import_device_fixture.sh heavy_user
tool/import_device_fixture.sh offline_user
tool/import_device_fixture.sh experiment_user
tool/import_device_fixture.sh privacy_user
```

The default target is the booted Simulator and the default bundle ID is
`jp.sunrise.signalpath`. Install and open the app once before the first import
so its data container and `Documents` directory exist. The script terminates
the Simulator app, backs up the old database and SQLite sidecars, atomically
installs `ai_opportunity_radar_local.db`, runs SQLite validation when
`sqlite3` is available, and compares the installed file byte-for-byte. It
prints success only after these checks pass. Without `--launch`, open the app
manually after import; the first launch upgrades fixture schema v32 to the
current local schema.

Backups are private QA data and use owner-only permissions under
`frontend_flutter/build/device_fixture_backups/`. Delete them through the
normal local build-artifact cleanup after the QA evidence is no longer needed.

### Physical device

For a connected development device with `ios-deploy`:

```sh
tool/import_device_fixture.sh privacy_user --device DEVICE_UDID
```

The script verifies the app is installed, stops it, downloads `Documents` as a
backup, removes only the database and its known sidecars, uploads the fixture,
downloads `Documents` again, and verifies the copied DB. If app termination
cannot be confirmed, force-quit Signal Path and rerun with
`--device-app-stopped`. Any backup, upload, read-back, byte comparison, or
sidecar check failure exits nonzero and is **not** reported as success.

`devicectl` can copy an app data container but does not provide the same safe,
generic per-file SQLite-sidecar cleanup. Therefore the importer exposes an
explicit non-writing plan instead of pretending it completed an import:

```sh
tool/import_device_fixture.sh privacy_user \
  --device DEVICE_UDID \
  --device-method devicectl-plan
```

That command exits with status 3 after printing backup/copy commands and the
sidecar precondition. Prefer installing `ios-deploy` for the verified one-step
physical-device path. Use `--dry-run` with either target to validate a fixture
and inspect the plan without writing a container.
