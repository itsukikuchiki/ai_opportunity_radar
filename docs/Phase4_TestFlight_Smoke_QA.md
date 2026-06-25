# Phase 4 TestFlight Smoke QA

Date: 2026-06-18

Scope: prepare the next major TestFlight validation package for Phase 3+ / Phase 4 platform QA. This version is for platform validation first, not production release sign-off.

## Target Version

| Field | Value |
| --- | --- |
| Target marketing version | 4.0.0 |
| Target build number | 5 |
| Target ASC display version | 4.0.0, or 4.0 if App Store Connect normalizes the short version |
| Bundle ID | jp.sunrise.signalpath |
| Purpose | TestFlight platform validation |
| Production ready | No |

## Current Status

| Area | Status |
| --- | --- |
| Engineering validation for `4.0.0` package | Passed |
| IPA build | Passed |
| App Store Connect upload | Passed |
| TestFlight internal group link | Passed |
| Real-device smoke test | Pending |
| Platform QA | Open |
| Production ready | No |

## Version Sources

| Area | Required value | Status |
| --- | --- | --- |
| `frontend_flutter/pubspec.yaml` | `version: 4.0.0+1` | Updated |
| iOS `CFBundleShortVersionString` | `$(FLUTTER_BUILD_NAME)` -> `4.0.0` | Derived from Flutter build |
| iOS `CFBundleVersion` | `$(FLUTTER_BUILD_NUMBER)` -> `1` | Derived from Flutter build |
| Runner Release `CURRENT_PROJECT_VERSION` | `$(FLUTTER_BUILD_NUMBER)` | Already configured |
| Fastlane / build scripts | No repo Fastfile found | Not applicable |
| App Store Connect version record | `4.0.0` | Created |

## App Store Connect Version Setup

Create or confirm an iOS App Store version:

- Version: `4.0.0`
- Build to upload: `4.0.0 (5)`
- Use this version for TestFlight platform validation.

Do not unnecessarily create a new version if ASC already has `4.0.0`.

Current ASC result:

```text
HTTP 201
App Store version id: 7b5d5c8b-2cdf-49d7-8537-23658de089a8
Version: 4.0.0
State: PREPARE_FOR_SUBMISSION
Release type: AFTER_APPROVAL
```

## 4.0.0 (5) Build / Upload Result

Latest icon refinement validation package generated on 2026-06-21:

```text
flutter analyze: passed
git diff --check: passed
AppIcon PNG validation: RGB / no alpha
```

Build result:

```text
Version Number: 4.0.0
Build Number: 5
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload / TestFlight result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 20f7f71a-eff8-4692-a3e0-1ec618d2affa
Processing state: VALID
Internal group link: HTTP 204
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
```

Icon update note:

```text
The AppIcon master and AppIcon.appiconset assets were regenerated to remove
the visible white outer ring on SpringBoard. The icon artwork now fills the
iOS rounded icon tile more fully and includes a subtle glossy highlight.
```

## 4.0.0 (4) Build / Upload Result

Latest validation package generated on 2026-06-21:

```text
flutter clean: passed
flutter pub get: passed
flutter analyze: passed
flutter test --no-pub: 144 passed
backend python3 -m pytest: 33 passed
git diff --check: passed
```

Build result:

```text
Version Number: 4.0.0
Build Number: 4
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload / TestFlight result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 01e66554-278e-4458-b989-90b63d889394
Processing state: VALID
Internal group link: HTTP 204
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
```

## 4.0.0 (1) Build / Upload Result

Engineering validation was rerun for the `4.0.0` package:

```text
flutter clean: passed
flutter pub get: passed
flutter analyze: passed
flutter test --no-pub: 134 passed
backend python3 -m pytest: 33 passed
git diff --check: passed
```

Build result:

```text
Version Number: 4.0.0
Build Number: 1
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 409a8c43-015d-4952-8625-e15ab3937e8f
Processing state: VALID
```

Upload note:

```text
The first upload attempt failed because Apple required
NSHealthUpdateUsageDescription. This was fixed in Info.plist and the IPA was
rebuilt before the successful upload.
```

## TestFlight Internal Distribution Path

Use the corrected App Store Connect API relationship path, not `fastlane pilot distribute --groups`.

Known groups:

| Group | ID | Type |
| --- | --- | --- |
| Signal Path Internal Testers | `da65b43f-8a52-4152-b1fb-1251d03e153f` | Internal |
| Signal Path External Testers | `df83a0c7-0dc1-42ec-8031-ba75e450bee5` | External |

After uploading a new `4.0.0` build, link the build to the internal group:

```text
POST /v1/betaGroups/da65b43f-8a52-4152-b1fb-1251d03e153f/relationships/builds
data: [{ type: "builds", id: "<4.0.0 build id>" }]
```

Current link result:

```text
Build id: 409a8c43-015d-4952-8625-e15ab3937e8f
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
Link response: HTTP 204
Verification: build appears in internal group builds list, processingState VALID
```

Do not use:

```bash
fastlane pilot distribute --groups "Signal Path Internal Testers"
```

Reason: in this fastlane version, `--groups` is tied to external tester distribution behavior and can trigger beta review submission.

## Required TestFlight Smoke QA

Do not mark Platform QA as passed until these are verified on TestFlight / real device:

| Scenario | Status |
| --- | --- |
| Install TestFlight build `4.0.0 (5)` | Pending real-device confirmation |
| First launch and onboarding | Pending |
| Today input Signal | Pending |
| ScheduleSignal | Pending |
| Goal Practice | Pending |
| Weekly / Journey reads new data | Pending |
| AI failure still saves raw input | Pending |
| Quota exceeded still allows recording | Pending |
| Monthly Pro sandbox purchase | Pending |
| Yearly Pro sandbox purchase | Pending |
| Restore Purchase | Pending |
| Pro entitlement unlocks UI / quota | Pending |
| Sign in with Apple | Pending |
| Cloud backup upload | Pending |
| Delete app / reinstall / cloud restore | Pending |
| Delete account clears local + cloud + onboarding state | Pending |
| EventKit permission denied / authorized / revoked | Pending |
| HealthKit permission denied / authorized / revoked | Pending |
| Keyboard avoids composer and sheets | Pending |
| Floating bottom nav does not cover controls | Pending |
| Dynamic Island / safe area check | Pending |
| Real-device screenshot evidence | Pending |

## Exit Criteria

Phase 4 Platform QA can move to `Passed` only when:

1. `4.0.0 (5)` is visible and installable in TestFlight for internal testers.
2. IAP monthly/yearly purchase and restore are verified.
3. Sign in with Apple and cloud backup restore are verified.
4. EventKit and HealthKit native permission flows are verified.
5. Real-device UI safety checks pass.
6. Evidence screenshots or recordings are saved.

Until then:

- Engineering validation can be `Passed` after automated checks.
- TestFlight readiness can be `Yes, for validation use`.
- Platform QA remains `Open`.
- Production ready remains `No`.
