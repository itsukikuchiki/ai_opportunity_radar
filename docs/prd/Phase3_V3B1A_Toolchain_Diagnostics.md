# Phase 3 V3B-1A Toolchain Diagnostics

Date: 2026-05-29

## Summary

Status: Toolchain partial fix archived. Manual simulator evidence deferred to Release QA.

V3B-1A repaired the Flutter / Dart test toolchain and restored `flutter analyze` / `flutter test`.

The remaining blocker is iOS simulator launch through Xcode: `flutter run` reaches app launch, then Xcode fails while resolving Swift Package Manager dependencies.

## Before Repair

- Flutter SDK was on local `stable` at `3.29.3`, while `origin/stable` pointed to `3.44.0`.
- Local Flutter stable and `origin/stable` had diverged.
- `flutter --no-version-check` crashed the Dart VM with `runtime/vm/cpuinfo_macos.cc:42`.
- `flutter test` was blocked by Flutter's pre-test version check / `git fetch --tags`.

## Repair Actions

- Ran `git fetch --tags` in `/Users/yangyang/development/flutter`; it completed.
- Reset local Flutter stable to current remote stable with `git checkout -B stable origin/stable`.
- Rebuilt Flutter cache through `flutter --version`.
- Updated Flutter dependency compatibility:
  - `frontend_flutter/pubspec.yaml`: `intl: ^0.19.0` -> `intl: ^0.20.2`
  - regenerated `frontend_flutter/pubspec.lock` with `flutter pub get`.

## Current Toolchain

```text
which flutter: /Users/yangyang/development/flutter/bin/flutter
which dart: /Users/yangyang/development/flutter/bin/dart
Flutter SDK path: /Users/yangyang/development/flutter
Flutter channel: stable
Flutter version: 3.44.0
Flutter revision: 559ffa3f75
Dart version: 3.12.0
Xcode version: 26.3 (17C529)
xcode-select: /Applications/Xcode.app/Contents/Developer
Flutter SDK git status: ## stable...origin/stable
Flutter tag: 3.44.0
```

Booted simulator during verification:

```text
iPhone 17 Pro (791DD8B4-2B1F-4D9A-8CEF-14ED6F91257A), iOS 26.1
```

## Verification

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter analyze
flutter test
flutter test test/features/pages/today/today_v3b_manual_evidence_test.dart
```

Results:

- `flutter analyze`: no issues found.
- `flutter test`: `40 passed`.
- `today_v3b_manual_evidence_test.dart`: `3 passed`.

## V3B Evidence Test Coverage

File:

- `frontend_flutter/test/features/pages/today/today_v3b_manual_evidence_test.dart`

Coverage:

- Today renders online SignalCard data.
- Today renders backend-unreachable local drafts.
- Timeline renders migrated legacy SignalCards.
- Timeline verifies `local_date` grouping after scrolling to the legacy section.
- Confirmation action writes `accurate`.
- Correction action writes `edited` and `user_correction_json`.
- Old saved AI reply is displayed and not regenerated.

## Additional UI Fix Found During Evidence

File:

- `frontend_flutter/lib/features/pages/today/today_page.dart`

Fix:

- Moved the correction dialog `TextEditingController` into a dedicated `_CorrectionDialog` state object.
- This prevents `TextEditingController was used after being disposed` during dialog closing on Flutter 3.44.

## Remaining Blocker

Simulator launch still cannot produce accepted Today screenshots because Xcode fails before the evidence app becomes visible.

Observed command:

```bash
flutter run -d 791DD8B4-2B1F-4D9A-8CEF-14ED6F91257A -t tool/v3b_evidence_app.dart
flutter run -d F74BF2DC-C556-402D-ADE8-687D545C251C -t tool/v3b_evidence_app.dart
```

Observed process:

```text
xcodebuild -clonedSourcePackagesDirPath /Users/yangyang/ai_opportunity_radar/frontend_flutter/build/ios/SourcePackages -resolvePackageDependencies
```

Result:

```text
Error: Xcode failed to resolve Swift Package Manager dependencies
```

Also observed:

```text
CoreSimulatorService connection became invalid
simdiskimaged crashed or is not responding
```

Screenshot attempt:

- `/private/tmp/signalpath_v3b_evidence/v3b_evidence_simulator_current.png`
- This screenshot only shows the simulator Apple boot screen, so it is not valid Today UI evidence.

Conclusion:

- Flutter / Dart test toolchain is repaired.
- V3B UI behavior is covered by automated widget evidence.
- Manual simulator screenshot/recording remains blocked by Xcode/CoreSimulator package-resolution state.

Archive decision:

- V3B-1A is archived as a partial toolchain fix.
- Release QA must keep the Xcode/CoreSimulator/SPM blocker open until a real simulator, real device, or CI run can provide Today UI screenshots or recording.
