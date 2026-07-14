# P2.1-20 Privacy, Network, Performance, Rollback Prep

Status: automated non-functional gates are ready. Real network quality, app
lifecycle, device VoiceOver behavior, crash collection, and rollback drills
still need device/staging execution.

## Privacy And Permissions

| Check | Status | Evidence / test |
| --- | --- | --- |
| Permission prompts are localized | Ready | `InfoPlist.strings` supplies English, Simplified Chinese, Traditional Chinese, and Japanese copy for Speech, Microphone, Photos, Health, and retained Calendar keys. |
| Speech is on-device only | Ready | Native recognition selects only a recognizer that supports on-device recognition and sets `requiresOnDeviceRecognition = true`; unavailable languages fall back to manual text input, not network recognition. |
| HealthKit permission copy is clear | Ready | Advanced Signals explains that HealthKit only produces abstract recovery hints; raw health details are not displayed, uploaded, or placed in Signal Library. Authorization uses `toShare: nil`. The required update-purpose key is retained but explicitly states that Signal Path does not add or modify Health data. |
| Only abstract Health hints are generated | Ready | `HealthRecoverySignalRepository` outputs allowlisted aggregate recovery hints only. |
| Calendar is not a current user feature | Ready | The Advanced Signals UI has no Calendar entry. Compatibility repositories and the iOS bridge remain future-Target code only and their hints are excluded from current Energy Budget and candidate planning. The runtime never requests EventKit authorization; it can only read abstract busy blocks if the device was already authorized outside this flow. Calendar is excluded from this QA round, and any Calendar permission sheet is a failure. |
| Turning permissions off does not crash | Ready | Denied / not requested / unavailable paths return internal Energy Budget fallback statuses. |
| Excluded content does not enter trace evidence | Ready | `EligibilityService`, privacy exclusion, soft delete, and stale propagation tests cover exclusion from higher-level analysis / trace evidence. |
| Four-language UI at 1.3x text | Automated | Release guardrails render Today, Weekly, Experiment, Journey, Me, and Signal Library in English, Simplified Chinese, Traditional Chinese, and Japanese with a 1.3 text scaler and fail on overflow. |
| Touch and VoiceOver contracts | Automated + device confirmation pending | Release guardrails require 44x44 minimum targets and explicit button/selected/tap semantics for bottom navigation and Today quick-record controls. Final spoken order and pronunciation remain a physical-device check. |

Reference tests:

```sh
flutter test \
  test/core/api/repositories/calendar_schedule_density_repository_test.dart \
  test/core/api/repositories/health_recovery_signal_repository_test.dart \
  test/core/api/repositories/energy_budget_repository_test.dart \
  test/core/eligibility/signal_eligibility_service_test.dart \
  test/core/local/local_capture_repository_test.dart
```

## Network Scenarios

| Scenario | Current preparation | Real-device action |
| --- | --- | --- |
| Normal network | API repositories and backend contract tests cover happy paths. | Run Today -> Weekly Reflect -> save experiment -> feedback -> Journey evidence on staging. |
| Weak network | Local draft / retry identity and `sync_failed` states exist. | Use Network Link Conditioner or throttled proxy; verify no duplicate SignalCard and debug shows `client_id`. |
| Offline | Local draft path saves on device and reports sync later. | Disable network, create Today Signal, reopen app, verify local draft and no high-level analysis inclusion until sync policy allows. |
| Airplane mode | Same as offline; device-specific prompt behavior must be tested manually. | Toggle airplane mode before save and during retry. |
| Request timeout | `last_error`, `sync_failed`, and pipeline error fields are visible in Debug Trace. | Inject timeout through staging proxy or server delay; verify no crash and retry keeps same `client_id`. |
| Background -> foreground | Build/profile supports staging/internal diagnosis; lifecycle is a manual QA item. | Start save or sync, background app, return, verify state is not duplicated. |
| Repeated save taps | `client_id` / sync identity is the dedupe contract. | Tap save repeatedly under slow network; verify one local SignalCard and one remote identity. |
| Delete during sync | Tombstone and stale propagation exist. | Delete while sync is pending; verify tombstone blocks old remote resurrection. |
| Restore after delete | Restore API/local restore paths exist. | Restore deleted Signal; verify trace state and stale reasons update. |
| Old remote data returns | Tombstone state blocks resurrection unless explicit restore. | Replay old remote row after delete; verify Debug Trace shows active tombstone and no active evidence. |

Manual device fixtures:

- `offline_user.db`: local draft, retry `client_id`, `sync_failed`.
- `privacy_user.db`: privacy exclusion, tombstone, inactive trace, stale rows.
- `legacy_user.db`: old remote/legacy compatibility data.

The six account fixtures can be imported without manually locating an app
container:

```sh
cd frontend_flutter
tool/import_device_fixture.sh --list
tool/import_device_fixture.sh heavy_user --simulator booted --launch
tool/import_device_fixture.sh privacy_user --device DEVICE_UDID
```

The importer terminates the app, creates a private backup, removes SQLite
sidecars, installs the selected database, runs `PRAGMA quick_check`, and
verifies the copied database. Simulator replacement is atomic; a physical-device
run reports success only after a byte-for-byte read-back. See
`docs/active/device_test_accounts.md`.

## Performance Baseline

`backend/tests/test_large_legacy_migration_performance.py` is the automated
regression gate. It creates an actual historical SQLite database using deployed
Alembic `0002` plus the unmodified legacy SQL `006`-`019`, inserts 2,000
SignalCards before the backfills, upgrades to current Alembic head, asserts an
empty ORM schema diff and content digest, then reads through the real Today,
Weekly, and Journey repositories. It never substitutes current
`metadata.create_all()` for the old schema.

| Operation | Soft CI limit | 2026-07-14 reference run |
| --- | ---: | ---: |
| Historical DB -> current head | 30 s | 1.701 s |
| Today recent SignalCards | 12 s | 1.457 s |
| Weekly period summary | 8 s | 0.105 s |
| Journey first evidence date | 8 s | 0.123 s |

These are deliberately wide regression limits, not product latency promises.
They catch runaway retries, per-row remote work, and severe query regressions
without making shared CI runners flaky. Device launch/render timing remains a
separate QA observation.

| Baseline | Current preparation | Validation |
| --- | --- | --- |
| Today first screen does not block on migration | 2,000-row historical migration plus real Today repository read has a soft CI limit. | Import `legacy_user` and `heavy_user`; verify the loading/failure shell remains usable while the device performs its local migration. |
| Weekly does not scan unrelated data | Real week-bounded summary over the 2,000-row upgraded database has a soft CI limit. | Use `heavy_user`; generate Weekly for one week and watch Debug Trace / profiler. |
| Journey does not become linear with all historical Signals | Real Journey evidence-date read over the 2,000-row upgraded database has a soft CI limit. | Open Journey with `heavy_user` and confirm month view remains responsive. |
| Evidence drilldown query is acceptable | `trace_links` indexes exist; Debug Trace and Journey evidence tests cover drilldown. | Tap evidence repeatedly on `experiment_user.db`; verify no visible stall. |
| 2,000+ signals do not crash | Historical upgrade, integrity, Today/Weekly/Journey repository reads, and `heavy_user.db` fixture are automated. | Smoke Today / Weekly / Journey / Debug Trace on device. |
| DB migration has loading/fallback, not black screen | Migration fixtures cover old schemas and missing trace/legacy fields. | Install over old DB fixture and record launch behavior. |

Suggested device pass order:

1. `fresh_user`
2. `legacy_user`
3. `heavy_user`
4. `offline_user`
5. `experiment_user`
6. `privacy_user`

## Rollback Plan

| Failure | Prepared rollback behavior |
| --- | --- |
| Migration fails or old data is incomplete | Do not drop old fields/tables in P2.1. Use legacy fixtures to reproduce; ship hotfix that keeps fallback reads and marks affected generated rows stale. |
| `reflection_results` read fails | Weekly/Journey can fall back to snapshot fields or empty/generated-safe UI rather than black screen. Mark reflection stale and regenerate when possible. |
| `experiment_candidates` missing | Weekly keeps `opportunitySnapshot['_life_experiment']` as old-data fallback only; saving still creates formal `life_experiments`. |
| `trace_links` missing | Journey/evidence UI shows empty or legacy/fallback evidence state; it must not fabricate evidence. |
| New endpoint fails | `/api/v1/ai/reflect-weekly` is canonical; `/api/v1/ai/deep-weekly` remains compatibility endpoint. If canonical fails due to rollout, use compatibility endpoint while telemetry tracks old usage. |
| Soft delete rollout problem | Tombstone columns are additive. Keep delete/restore compatibility and avoid physical removal until staging/prod telemetry is clean. |
| Prompt/model rollout problem | `reflection_version_registry` can mark old rows stale; rollback by restoring registry versions or regenerating affected reflections. |

## Release Gate

Before marking P2.1 ready for real-device QA:

1. Run the reference tests above.
2. Run `python3 -m pytest backend/tests/test_large_legacy_migration_performance.py -q`.
3. Run device smoke with all six P2.1-17 account fixtures using the importer.
4. Confirm staging migration and legacy telemetry in `docs/active/staging_backend_confirmation.md`.
5. Capture Debug Trace screenshots for at least one normal, one offline, one deleted/restored, and one missing-trace scenario.
6. Confirm crash/network logs collection path from Xcode or Console using only privacy-safe event and request IDs.
