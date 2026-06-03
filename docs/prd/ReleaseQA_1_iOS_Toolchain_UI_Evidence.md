# ReleaseQA-1 iOS Toolchain / UI Evidence

Date: 2026-05-30

Scope: fix the iOS simulator / Xcode / SwiftPM blocker and produce Phase 3 pre-release UI evidence. This round adds no product feature, no UI redesign, and no real EventKit / HealthKit integration.

## 1. Status

| Area | Result |
| --- | --- |
| Xcode first launch components | Fixed. `xcodebuild -runFirstLaunch` changed from install failure to `Install Succeeded`. |
| SwiftPM resolution | Fixed for this run. `xcodebuild -resolvePackageDependencies` completed with `resolved source packages:`. |
| CoreSimulator boot | Fixed for this run. iOS 18.5 iPhone 16 Plus booted successfully. |
| Apple-logo-only screenshots | Fixed. Simulator screenshots now show rendered Flutter UI. |
| Phase 3 UI evidence | Generated as screenshots under `/private/tmp/signalpath_releaseqa_phase3/`. |

ReleaseQA-1 can be treated as toolchain fixed for the current machine state. Before an App Store/TestFlight submission, repeat the test commands below because Flutter upgraded iOS project files during the simulator build.

## 2. Toolchain Diagnostics

| Command | Result |
| --- | --- |
| `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` |
| `xcodebuild -version` | `Xcode 26.3`, build `17C529` |
| `xcodebuild -runFirstLaunch` | `Install Succeeded` after cleanup |
| `xcrun simctl list devices booted` | `iPhone 16 Plus (660B1665-C332-4912-ABB0-46EEA020EAD0) (Booted)` |
| `flutter --version` | Flutter `3.44.0` stable, Dart `3.12.0` |
| `dart --version` | Dart SDK `3.12.0` stable on `macos_x64` |
| `flutter doctor -v` | Flutter/Xcode path usable; Android SDK issue remains unrelated to iOS Release QA |

Initial sandbox-only Dart check failed because the sandbox could not write Flutter SDK cache files. The same version check passed with normal local permissions.

## 3. Cleanup / Rebuild Actions

Completed:

- Cleared Xcode DerivedData.
- Cleared SwiftPM caches.
- Removed stale iOS `SourcePackages` / `.swiftpm` state.
- Shut down simulators.
- Restarted Simulator / CoreSimulator related services.
- Re-ran `flutter pub get`.
- Re-ran `pod install`.
- Re-ran `xcodebuild -resolvePackageDependencies`.
- Ran `flutter run` on iOS simulator successfully.

Flutter 3.44 automatically upgraded iOS project metadata during `flutter run`:

- minimum iOS deployment target moved from `12.0` to `13.0`.
- Flutter local Swift Package integration was added.
- the CocoaPods embed-framework build phase was removed by the Flutter upgrade path.

The app still builds and runs on simulator after these changes. Flutter currently prints a migration notice that the project still has CocoaPods integration while all plugins are Swift Packages. This is not blocking ReleaseQA-1, but should be reviewed before the next production archive.

## 4. Automated Verification

| Command | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 108 passed |
| `python3 -m pytest` in backend | 29 passed |
| `git diff --check` | Clean |
| `flutter build ios --simulator -t tool/releaseqa_phase3_evidence_app.dart` | Built `build/ios/iphonesimulator/Runner.app` |

Backend pytest produced cache-write warnings under sandbox permissions, but the test suite completed with 29 passed.

## 5. UI Evidence Files

Evidence directory:

`/private/tmp/signalpath_releaseqa_phase3/`

| File | Coverage |
| --- | --- |
| `01_today_v3b_evidence.png` | Production Today evidence entrypoint: local draft message, empty state, Today Summary block rendered in simulator |
| `02_phase3_scene_current.png` | Today Summary / inclusion / correction evidence |
| `03_phase3_scene_next.png` | Journey Review & Adjust evidence |
| `04_phase3_scene_next.png` | Advanced Energy Boundary evidence |
| `05_phase3_scene_next.png` | Weekly one-pattern / one-experiment / Energy Budget evidence |
| `06_phase3_scene_next.png` | Signal Library curated pattern / save-to-observation privacy evidence |
| `07_phase3_scene_next.png` | Weekly one-pattern / one-experiment / Energy Budget evidence |
| `08_phase3_scene_next.png` | Journey Review & Adjust evidence |
| `09_phase3_scene_next.png` | Life Experiment save / skipped / not-helpful feedback evidence |
| `10_phase3_scene_today_inbox.png` | Additional carousel capture; duplicate Weekly scene |

`tool/releaseqa_phase3_evidence_app.dart` is an evidence-only simulator harness. It does not change production navigation or product behavior. Production code paths remain covered by the automated tests above.

## 6. Scenario Coverage

| Scenario | Evidence |
| --- | --- |
| Today new record / SignalCard entry | `01_today_v3b_evidence.png`; `flutter test` Today V3B evidence tests |
| Backend unreachable local draft / retry language | `01_today_v3b_evidence.png`; `flutter test` Today repository retry test |
| Diary Timeline / legacy import | `01_today_v3b_evidence.png`; Today V3B evidence tests |
| Today Summary | `01_today_v3b_evidence.png`, `02_phase3_scene_current.png` |
| Weekly one-pattern / one-experiment | `05_phase3_scene_next.png`, `07_phase3_scene_next.png` |
| Life Experiment save / skip / feedback semantics | `09_phase3_scene_next.png`; Weekly repository tests |
| Journey Review & Adjust | `03_phase3_scene_next.png`, `08_phase3_scene_next.png` |
| Energy Budget block | `05_phase3_scene_next.png`, `07_phase3_scene_next.png` |
| Signal Library | `06_phase3_scene_next.png` |
| Save to my observation / library_saved SignalCard boundary | `06_phase3_scene_next.png`; Signal Library repository and Today widget tests |
| Advanced Energy external hints privacy boundary | `04_phase3_scene_next.png` |

The simulator screenshot set verifies rendering and copy. Direct finger/tap-through on a production build is still recommended before TestFlight, but the previous CoreSimulator / SPM blocker is no longer preventing screenshots on this machine.

## 7. Remaining Release QA Notes

- Repeat `flutter analyze`, `flutter test`, backend pytest, and an iOS simulator build after any further iOS project changes.
- Review Flutter 3.44 SwiftPM/CocoaPods migration warnings before archive.
- If App Store/TestFlight archive fails, inspect the iOS 13 deployment target and Flutter Swift Package integration changes first.
- Real-device verification remains useful for purchase flow and TestFlight-specific behavior; ReleaseQA-1 did not re-test StoreKit purchase.

## 8. Do Not Mislabel

- This closes the previous Xcode/CoreSimulator/SPM screenshot blocker for simulator evidence on the current machine.
- This does not mean App Store purchase flow is verified.
- This does not mean real EventKit / HealthKit permissions are implemented.
- This does not mean raw Calendar / Health data enters the app; V3G remains abstract-hint only.
