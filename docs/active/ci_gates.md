# P2.1 CI Gates

P2.1 splits CI into named gates so failures point to the broken product layer
instead of one large undifferentiated test job.

| Gate | Purpose | Commands |
| --- | --- | --- |
| `ci-static` | Test-manifest completeness, formatting, analyzer, and Python syntax baseline. | `bash scripts/check_ci_test_manifest.sh`, `dart format --set-exit-if-changed lib test`, `flutter analyze`, `python3 -m compileall -q backend/app backend/tests` |
| `ci-flutter-core` | Flutter repository/model/data-service behavior. | Focused `flutter test` over core local repositories, API repositories, eligibility, Energy Budget, Signal Library, and advanced hint boundaries. |
| `ci-flutter-migration` | Local DB migration, stale propagation, and legacy fallback counters. | DB fixture builder/self-check, legacy migration, cache invalidation, fallback monitor tests. |
| `ci-flutter-ui-smoke` | Critical page rendering, localization, accessibility, and interaction smoke tests. | Today, Weekly, Life Experiment, Journey, Me, Signal Library, Advanced Signals, Debug Trace, initialization failure, four-language 1.3x rendering, 44pt targets, VoiceOver semantics, and shell navigation. |
| `ci-backend-core` | Backend domain, API core behavior, observability, performance, and authoritative schema migration. | Signal eligibility, SignalCard migration/service tests, request-ID/privacy-safe failures, 2,000-row legacy upgrade plus Today/Weekly/Journey soft limits, purchase entitlement persistence, reflection repository, Self Review, and PostgreSQL 16 legacy-to-head schema contracts. |
| `ci-legacy-compatibility` | Legacy compatibility and telemetry boundaries. | Flutter legacy fallback/migration tests plus backend legacy telemetry, backup/account, DeepWeekly compatibility, and old API chain tests. |
| `ci-main-flow` | End-to-end main product chain. | Flutter P2.1-14 three main-chain integration tests plus backend API chain integration. |

The GitHub Actions workflow is `.github/workflows/p2-1-ci-gates.yml`. Flutter is
pinned to `3.44.0` (Dart `3.12.0`) so a future `stable` channel update cannot
silently change the candidate result. Python is pinned to `3.12`, and the
PostgreSQL migration gate uses PostgreSQL `16`.

Pushes to `codex/testflight-candidate-*` run the same seven gates as `main`.
This verifies the exact candidate HEAD SHA from a clean checkout before merge;
PR merge-ref checks remain useful integration evidence but are not a substitute
for the candidate-SHA run.

`ci-backend-core` starts a disposable PostgreSQL 16 service. It must replay the
unmodified legacy SQL `006`–`019` path and the already-deployed Alembic `0007`
path to current head, preserve sentinel data, and finish with an exact empty
ORM metadata diff. SQLite migration tests remain the fast portable layer, not
a substitute for this PostgreSQL gate.

The 2,000-row soft performance gate intentionally runs on a real historical
SQLite file because it validates the independently deployed `006`-`019` chain
and repository behavior without needing runner-specific production hardware.
It complements, rather than replaces, the PostgreSQL schema contract and the
physical-device launch smoke.

## Gate Policy

- `ci-static` should be required on every PR.
- `ci-main-flow`, `ci-flutter-migration`, and `ci-legacy-compatibility` are release-blocking for V4/P2.1 data-flow changes.
- `ci-flutter-ui-smoke` is release-blocking for page/UI route changes.
- `ci-backend-core` is release-blocking for backend API, model, repository, migration, and telemetry changes.
- `ci-flutter-core` is release-blocking for Flutter data, local DB, repository, and AI orchestration changes.
- `scripts/check_ci_test_manifest.sh` fails when a Flutter/backend test is not assigned to any gate or when a gate references a deleted test file.
- A passing manifest proves test discovery/assignment completeness; the feature matrix and real-device boundary still decide whether the tests cover the accepted product contract.
