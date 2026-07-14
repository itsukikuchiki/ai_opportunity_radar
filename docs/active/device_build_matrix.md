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
| `API_BASE_URL` | URL | Overrides the default production backend. |

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
