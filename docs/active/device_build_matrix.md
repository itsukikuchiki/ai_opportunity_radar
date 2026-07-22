# P2.1 Device Build Matrix

P2.1 real-device testing uses four build profiles. Dart defines control app/API
behavior, while the selected shared Xcode scheme independently controls whether
Xcode attaches a local StoreKit fixture. These two axes must not be conflated.

| Build | Purpose | Mode | Debug tools | API |
| --- | --- | --- | --- | --- |
| Debug / Internal | Engineer/device diagnosis with Trace Debug, fallback counters, and pipeline state visible. | `--debug` | On | Staging by default |
| Release-like | Real-user simulation with production endpoint and no debug page. | `--release` | Off | Production by default |
| Staging | TestFlight-style validation against staging data with diagnostics enabled. | `--profile` | On | Staging by default |
| Production-like | Final production behavior check before submission. | `--release` | Off | Production by default |

## Xcode StoreKit Schemes

| Scheme | StoreKit source | Use |
| --- | --- | --- |
| `Runner` | No local StoreKit configuration | Default. Use for normal physical-device work, App Store Connect/Sandbox checks, archives, TestFlight, and release validation. |
| `Runner-LocalStoreKit` | `ios/SignalPath.storekit` | Explicit local Xcode subscription simulation only. Do not use for TestFlight evidence. |

An Xcode launch with `Runner` uses the StoreKit environment supplied by the
actual installation/purchase channel; “real” here means **not the local Xcode
StoreKit file**, not necessarily App Store Production. A TestFlight build uses
its Sandbox purchase environment. A released App Store build uses Production.

TestFlight archives must use `Runner`. The `SignalPath.storekit` file is an
Xcode launch fixture and is not an application resource. Never treat a purchase
or restore made with `Runner-LocalStoreKit` as a TestFlight restore result.

## Dart Defines

| Define | Values | Notes |
| --- | --- | --- |
| `SIGNALPATH_BUILD_PROFILE` | `internal`, `release-like`, `staging`, `production-like` | Reader-facing build identity. |
| `SIGNALPATH_ENABLE_DEBUG_TOOLS` | `true` / `false` | Controls Trace Debug visibility outside normal debug mode. |
| `SIGNALPATH_ENABLE_PIPELINE_LOGS` | `true` / `false` | Reserved switch for internal pipeline log surfaces. |
| `SIGNALPATH_QA_SHOWCASE_DATA` | `true` / `false` | TestFlight review fixture. Seeds isolated local demo evidence for Weekly/Journey/Pro and unlocks an in-memory Pro preview. Never use for a production App Store archive. |
| `API_BASE_URL` | URL | Overrides the default production backend. |

## TestFlight Showcase Build

The review-only TestFlight package may enable
`SIGNALPATH_QA_SHOWCASE_DATA=true`. On first launch it adds namespaced local
fixture rows without replacing user rows, marks onboarding complete, and makes
the current Weekly, Journey, deep-analysis, 小实验, and 目标
states inspectable immediately. The fixture is idempotent for the same local
day and owns only rows whose identifiers use the `qa_demo_` namespace.

The QA Pro preview is memory-only: it does not write a StoreKit entitlement or
modify restore-purchase state. StoreKit purchase and restore acceptance must
still be run separately with a normal `Runner` TestFlight build. A production
App Store archive must omit this define (the default is `false`).

### Current internal candidate: `4.0.0 (14)`

The user-authorized build `14` is a release archive made with the `Runner`
scheme, staging API, debug surfaces disabled, and QA showcase data enabled:

```sh
flutter build ipa --release --build-name=4.0.0 --build-number=14 \
  --dart-define=SIGNALPATH_QA_SHOWCASE_DATA=true \
  --dart-define=SIGNALPATH_BUILD_PROFILE=staging \
  --dart-define=SIGNALPATH_ENABLE_DEBUG_TOOLS=false \
  --dart-define=SIGNALPATH_ENABLE_PIPELINE_LOGS=false \
  --dart-define=API_BASE_URL=https://aiopportunityradar-staging.up.railway.app
```

This combination is intentional: it gives internal testers deterministic
Weekly, Journey, Pro, 小实验, and 目标 content while keeping the archive close to
release behavior. The seeded rows are local QA fixtures, not proof of staging
data generation, long-term accumulation, or StoreKit entitlement behavior.

Pre-archive engineering evidence recorded on 2026-07-23:

| Gate | Result |
| --- | --- |
| Flutter full suite | `595 / 595` passed |
| Flutter analyzer | Passed |
| Release UI guardrails | `11 / 11` passed; `320 / 390 / 430 / 768` widths, four languages at 1.3x, 44pt hit targets, and VoiceOver semantics |
| Backend suite | `104 passed / 2 PostgreSQL-only skipped` |
| Formatting, CI manifest, diff whitespace | Passed |

Delivery evidence recorded on 2026-07-23:

| Field | Result |
| --- | --- |
| Source commit | `f4c4321751432eea2f655c2bc469f661c4533b45` |
| Archive | `Runner`; `4.0.0 (14)`; bundle `jp.sunrise.signalpath`; minimum iOS `13.0` |
| Local StoreKit resource check | `SignalPath.storekit` absent from the IPA |
| App Store validation | Passed with no errors |
| Delivery / ASC build id | `771213e4-db8b-468f-8c39-11154f3e7e96` |
| Processing | `VALID`; not expired |
| Internal group | `Signal Path Internal Testers`; relationship verified |

These are automated engineering checks. VoiceOver speech order/pronunciation,
keyboard and safe-area behavior on hardware, HealthKit native permissions,
TestFlight Sandbox products, purchase, Restore Purchase, and entitlement/quota
refresh remain physical-device acceptance items.

## Build Script

From `frontend_flutter`:

```sh
tool/prepare_device_builds.sh print
tool/prepare_device_builds.sh build
```

The script prints or runs all four build commands. Override endpoints with:

```sh
STAGING_API_BASE_URL=https://your-staging.example \
PRODUCTION_API_BASE_URL=https://your-production.example \
tool/prepare_device_builds.sh build
```

## Acceptance Checklist

- `Runner.xcscheme` contains no `StoreKitConfigurationFileReference`.
- `Runner-LocalStoreKit.xcscheme` contains exactly one reference to `../SignalPath.storekit`.
- A TestFlight archive is made with `Runner`; local StoreKit transactions are absent from the installed TestFlight build.
- Internal build can open `/debug/trace` and show Trace Debug, fallback counters, trace links, reflection sources, and pipeline runs.
- Release-like build does not expose Trace Debug even if the route is opened directly.
- Staging build points to staging API and keeps diagnostic tools visible.
- Production-like build points to production API and keeps diagnostic tools hidden.
- Current native-permission scope follows [iOS native and privacy configuration](ios_native_privacy_configuration.md); Calendar is not part of this QA matrix and no Calendar prompt may appear.
