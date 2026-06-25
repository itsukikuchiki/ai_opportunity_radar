# Phase 3+ TestFlight Smoke QA

Date: 2026-06-18

Scope: prepare a TestFlight validation package for Phase 3+ platform smoke QA. This stage does not add features, does not redesign UI, and does not close production release readiness.

## Status

| Area | Status |
| --- | --- |
| Engineering validation | Passed |
| Platform QA mock / simulator pass | Partial |
| TestFlight validation IPA | Built and uploaded |
| TestFlight internal distribution | Linked to internal group |
| Real-device smoke test | Pending |
| Production ready | No |

## Build Package

| Field | Value |
| --- | --- |
| Version | 3.0.2 |
| Build | 1 |
| Bundle ID | jp.sunrise.signalpath |
| Team | 9S4L4FSR5Q |
| Archive | frontend_flutter/build/ios/archive/Runner.xcarchive |
| IPA | frontend_flutter/build/ios/ipa/SignalPath.ipa |
| IPA size | 34.3 MB |
| iOS deployment target | 13.0 |

Build command:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter build ipa --release
```

Result: release archive and App Store IPA export succeeded.

## App Store Connect Upload

Upload command:

```bash
xcrun altool --upload-app \
  --type ios \
  -f build/ios/ipa/SignalPath.ipa \
  --apiKey M6GRG3Q27V \
  --apiIssuer a78135b4-5bf6-4508-bd2c-5ca140eddaa8
```

Verification command:

```bash
fastlane run latest_testflight_build_number \
  app_identifier:jp.sunrise.signalpath \
  api_key_path:/private/tmp/signalpath_asc_api_key.json
```

Result: App Store Connect reports the latest upload for iOS as version `3.0.2`, build `1`.

## TestFlight Distribution Diagnosis

Internal tester group used from previous release docs:

- Group: `Signal Path Internal Testers`
- Previous group ID: `da65b43f-8a52-4152-b1fb-1251d03e153f`

Initial distribution command attempted:

```bash
fastlane pilot distribute \
  --app_identifier jp.sunrise.signalpath \
  --api_key_path /private/tmp/signalpath_asc_api_key.json \
  --app-platform ios \
  --app_version 3.0.2 \
  --build_number 1 \
  --groups "Signal Path Internal Testers" \
  --changelog "Phase 3+ Platform QA validation build. Engineering validation passed; platform smoke QA pending."
```

Result:

- Changelog was set successfully.
- Distribution did not complete.
- App Store Connect returned: `Cannot accept new beta review submission. This version and prior versions are closed for beta review submission. Please create a new version to upload a build for external testing.`

Interpretation:

- The binary upload exists in App Store Connect.
- `Signal Path Internal Testers` is an internal beta group.
- `Signal Path External Testers` is a separate external beta group.
- The `fastlane pilot distribute --groups ...` path is not appropriate for this internal-only validation pass because the `groups` option is tied to external testing behavior and triggered a beta review submission attempt.

## Internal Testing Fix

App Store Connect API inspection:

```text
APP id=6761879857 name=Signal Path：AI手帳
GROUP id=da65b43f-8a52-4152-b1fb-1251d03e153f name=Signal Path Internal Testers internal=true
GROUP id=df83a0c7-0dc1-42ec-8031-ba75e450bee5 name=Signal Path External Testers internal=false public=true
```

The latest uploaded build was directly linked to the internal group through the App Store Connect relationship API:

```text
POST /v1/betaGroups/da65b43f-8a52-4152-b1fb-1251d03e153f/relationships/builds
data: [{ type: "builds", id: "6973b792-d24f-4fdd-8df9-8af9c836af50" }]
```

Result: `HTTP 204`, which indicates the relationship write succeeded.

Follow-up verification:

```text
GROUP BUILDS:
BUILD id=6973b792-d24f-4fdd-8df9-8af9c836af50 build=1 processing=VALID uploaded=2026-06-03T18:38:23-07:00 expired=false
BUILD id=00710e4e-ecaf-4d0c-aab9-e77064705264 build=3 processing=VALID uploaded=2026-06-01T22:33:16-07:00 expired=false
BUILD id=49051bf9-5ff4-44ff-94ae-1e0a82976184 build=7 processing=VALID uploaded=2026-05-17T21:52:03-07:00 expired=false
```

Current interpretation:

- Build `3.0.2 (1)` is uploaded and `VALID`.
- Build `3.0.2 (1)` is linked to `Signal Path Internal Testers`.
- The prior blocker was not build/upload; it was the distribution tool path attempting external beta review.
- The next validation step is opening TestFlight on a tester device and confirming the build is visible/installable.

## Required Real-Device Smoke QA

Do not mark Platform QA as passed until these are verified on TestFlight / real device:

| Scenario | Status |
| --- | --- |
| Install TestFlight build `3.0.2 (1)` | Pending |
| First launch and onboarding | Pending |
| Today text signal save | Pending |
| Voice input transcript save | Pending |
| Schedule Signal input | Pending |
| Goal / practice feedback | Pending |
| AI failure still saves raw input | Pending |
| Quota exceeded still allows recording | Pending |
| Monthly Pro sandbox purchase | Pending |
| Yearly Pro sandbox purchase | Pending |
| Purchase cancellation / failure fallback | Pending |
| Restore Purchase with active subscription | Pending |
| Restore Purchase with no subscription | Pending |
| Pro entitlement unlocks UI / quota | Pending |
| Sign in with Apple native sheet | Pending |
| Sign in cancellation | Pending |
| Sign in success and token exchange | Pending |
| Cloud backup upload | Pending |
| Delete app / reinstall / cloud restore | Pending |
| Delete account clears local + cloud + onboarding state | Pending |
| EventKit permission denied / authorized / revoked | Pending |
| HealthKit permission denied / authorized / revoked | Pending |
| EventKit / HealthKit no-data fallback | Pending |
| Keyboard avoids composer and sheets | Pending |
| Floating bottom nav does not cover controls | Pending |
| Dynamic Island / safe area check | Pending |
| Small-screen and large-screen screenshots | Pending |

## Exit Criteria

Platform QA can move from `Open` to `Passed` only when:

1. A TestFlight build is installable on a real device.
2. IAP monthly/yearly purchase and restore are verified.
3. Sign in with Apple and cloud backup restore are verified.
4. EventKit and HealthKit native permission flows are verified.
5. Real-device UI safety checks pass.
6. Evidence screenshots or recordings are saved.

Until then:

- Engineering validation remains `Passed`.
- TestFlight readiness is `Yes, for validation use`.
- Platform QA remains `Open`.
- Production ready remains `No`.
