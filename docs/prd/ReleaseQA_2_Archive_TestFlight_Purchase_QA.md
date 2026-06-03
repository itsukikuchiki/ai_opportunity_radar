# ReleaseQA-2 Archive / TestFlight / Purchase QA

Date: 2026-05-30

Scope: verify the Phase 3 iOS release build/archive path, prepare TestFlight, and record purchase / Pro / quota QA status. This round adds no product feature, no UI redesign, and no real EventKit / HealthKit integration.

## 1. Status

| Area | Result |
| --- | --- |
| Clean dependency baseline | Passed |
| Frontend static check | Passed |
| Frontend tests | Passed |
| Backend tests | Passed |
| iOS release build | Passed |
| Xcode archive / IPA | Passed |
| TestFlight upload | Passed for `3.0.0 (1)` |
| Native purchase / restore on TestFlight device | Still requires real-device TestFlight QA |

ReleaseQA-2 closes the archive and TestFlight upload blocker. It does not close purchase QA until a tester installs `3.0.0 (1)` from TestFlight and verifies sandbox purchase / restore on device.

## 2. Commands And Results

| Command | Result |
| --- | --- |
| `flutter clean` | Passed |
| `flutter pub get` | Passed |
| `flutter analyze` | No issues found |
| `flutter test` | 108 passed |
| `python3 -m pytest` in `backend` | 29 passed |
| `flutter build ios --release` | Built `build/ios/iphoneos/Runner.app` |
| `flutter build ipa --release` | Built `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/SignalPath.ipa` |
| `fastlane pilot upload ...` | Uploaded and distributed `3.0.0 (1)` to Internal testers |

Backend pytest produced deprecation warnings and sandbox cache-write warnings only; all 29 tests passed.

## 3. Version / Build Notes

Initial upload attempt with `2.0.1` failed because App Store Connect rejected the closed train:

- `Invalid Pre-Release Train. The train version '2.0.1' is closed for new build submissions`
- `CFBundleShortVersionString [2.0.1] ... must contain a higher version than previously approved version [2.0.1]`

Resolution:

- `frontend_flutter/pubspec.yaml` was updated from `2.0.1+7` to `3.0.0+1`.
- New archive validation reported:
  - Version Number: `3.0.0`
  - Build Number: `1`
  - Display Name: `Signal Path`
  - Deployment Target: `13.0`
  - Bundle Identifier: `jp.sunrise.signalpath`

TestFlight upload result:

- App Store Connect app id: `6761879857`
- Uploaded version/build: `3.0.0 (1)`
- Processing result: `Successfully finished processing the build 3.0.0 - 1 for IOS`
- Distribution result: `Successfully distributed build to Internal testers`

## 4. iOS Deployment Target

| Source | Value |
| --- | --- |
| `frontend_flutter/ios/Podfile` | `platform :ios, '13.0'` |
| Xcode project `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` |
| Archive app settings validation | `Deployment Target: 13.0` |
| IPA Payload `MinimumOSVersion` | `13.0` |

Conclusion: iOS deployment target is internally consistent at `13.0`.

This is acceptable for the current Phase 3 QA baseline because Flutter 3.44 / iOS plugin Swift Package integration upgraded the project from iOS 12 to iOS 13 during ReleaseQA-1. If the product still needs to support iOS 12, that must become a separate compatibility decision and build investigation.

## 5. Signing / Bundle / Assets

| Item | Result |
| --- | --- |
| Bundle ID | `jp.sunrise.signalpath` |
| Team ID | `9S4L4FSR5Q` |
| Signing certificate | Cloud Managed Apple Distribution, expires `2027/04/09` |
| Provisioning profile | `iOS Team Store Provisioning Profile: jp.sunrise.signalpath`, expires `2027/04/09` |
| Entitlements | `application-identifier`, `beta-reports-active`, `team-identifier`, `get-task-allow = 0` |
| App icon | Present in `ios/Runner/Assets.xcassets/AppIcon.appiconset` including `1024x1024` |
| Launch screen | Present at `ios/Runner/Base.lproj/LaunchScreen.storyboard` |
| Supported devices | iPhone + iPad (`UIDeviceFamily` 1, 2) |

## 6. SwiftPM / CocoaPods Warning

Flutter prints:

`All plugins found for ios are Swift Packages, but your project still has CocoaPods integration.`

Observed impact:

- Did not block `flutter analyze`.
- Did not block `flutter test`.
- Did not block `flutter build ios --release`.
- Did not block `flutter build ipa --release`.
- Did not block TestFlight upload.

Action:

- Keep as a cleanup task before long-term release hygiene.
- Do not treat it as a ReleaseQA-2 blocker.

## 7. Privacy / Permissions Check

Current `Info.plist` does not request Calendar or Health permissions. This matches Phase 3 scope:

- real EventKit permission is not implemented.
- real HealthKit permission is not implemented.
- Calendar / HealthKit are still abstract hint prototypes only.

IPA contains privacy manifests from included Flutter / iOS plugin bundles, including:

- Flutter framework privacy manifest
- `in_app_purchase_storekit` privacy manifest
- `shared_preferences_foundation` privacy manifest
- `sqflite_darwin` privacy manifest
- `url_launcher_ios` privacy manifest

No raw Calendar / Health data is present in the shipped build path.

## 8. Purchase / Pro / Quota QA

### Verified By Code / Automated Tests

Purchase implementation currently supports:

- product ids:
  - `jp.sunrise.signalpath.pro.monthly`
  - `jp.sunrise.signalpath.pro.yearly`
- StoreKit product loading via `in_app_purchase`
- native StoreKit fallback through `signalpath/storekit`
- purchase activation in local `SharedPreferences`
- restore path through native StoreKit fallback or `in_app_purchase.restorePurchases`
- backend receipt verification endpoint `/api/v1/purchases/verify`
- sandbox receipt retry via Apple status `21007`
- local StoreKit test-data verification path

Quota implementation currently supports:

- Free:
  - `today_high_quality_reply`: daily 3
  - `weekly_basic`: weekly 1
  - `life_experiment_light`: weekly 1
- Pro:
  - `today_high_quality_reply`: monthly 150
  - `light_dialogue_turn`: monthly 60
  - `deep_weekly`: monthly 4
  - `journey_monthly_life_map`: monthly 2
  - `misunderstanding_check`: monthly 12
  - `gpt55_deep_upgrade`: monthly 10
- quota exceeded fallback without losing SignalCard input
- model usage logging without raw user text in metadata

Automated evidence:

- `backend/tests/test_phase3_signal_cards.py` covers quota exceeded fallback without losing input.
- backend pytest: 29 passed.
- frontend widget/repository tests cover premium-gated surfaces and Phase 3 non-loss flows.

### Still Requires Real Device / TestFlight

The following are not honestly complete until `3.0.0 (1)` is installed from TestFlight on a real device:

- App Store purchase sheet opens for Monthly Pro.
- App Store purchase sheet opens for Yearly Pro.
- sandbox purchase completes.
- restore purchase completes.
- failed/cancelled purchase leaves free Today recording usable.
- active Pro entitlement unlocks gated Pro UI in the TestFlight build.
- quota behavior after real Pro activation.

Reason: simulators and local archives cannot prove App Store sandbox purchase availability for the uploaded TestFlight binary.

## 9. Phase 3 Main-Chain QA Status

| Scenario | Current Status |
| --- | --- |
| Today new record | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Local draft / retry | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Diary Timeline | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Today Summary | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Weekly one-pattern / one-experiment | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Life Experiment save / skip / feedback | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Journey Review & Adjust | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Energy Budget block | Automated tests passed; simulator evidence from ReleaseQA-1 |
| Signal Library save to observation | Automated tests passed; simulator evidence from ReleaseQA-1 |
| `library_saved` SignalCard in Timeline | Automated tests passed |
| Real-device TestFlight walkthrough | Pending |

## 10. Remaining Blockers Before Production Submission

ReleaseQA-2 does not block TestFlight availability, but production submission should not proceed until:

- `3.0.0 (1)` is installed on a real device from TestFlight.
- purchase and restore are verified with sandbox Apple ID / TestFlight purchase flow.
- free user basic recording is checked after purchase cancellation / failure.
- Pro entitlement unlock behavior is checked after purchase / restore.
- Phase 3 main-chain smoke walkthrough is completed on the TestFlight build.

Explicitly not verified:

- real EventKit permission.
- real HealthKit permission.
- real Calendar data.
- real Health data.
- Calendar / HealthKit hints beyond abstract prototype tests.

## 11. Do Not Mislabel

- Archive and TestFlight upload are complete.
- Purchase QA is not complete yet.
- StoreKit product code paths exist, but real purchase availability must be proven from TestFlight.
- Calendar / HealthKit remain abstract-hint prototypes, not real platform integrations.
