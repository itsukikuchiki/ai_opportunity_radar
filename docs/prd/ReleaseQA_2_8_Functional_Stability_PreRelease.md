# ReleaseQA-2.8: Functional Chain And Pre-Release Stability

Status: Engineering stability check passed.

Scope: verify the Phase 3 functional chain, automated regression suite, and iOS release build path after the 2.7H visual lock. This round does not add product features, does not change the 2.7H visual baseline, does not add QA screenshots, and does not change purchase, Pro, quota, privacy boundaries, EventKit / HealthKit, Phase 3 data-chain logic, or eligible signal calculation.

## 1. Visual Lock Boundary

ReleaseQA-2.7H Final Fix remains the only visual baseline.

Do not proactively change:

- App Icon
- Splash
- LaunchImage
- primary background color
- primary color system

Allowed follow-up visual work is limited to pixel polish:

- spacing
- alignment
- button states
- text overflow
- multilingual wrapping
- Product Review screenshot polish

If later feature work drifts visually, use `ReleaseQA_2_7H_Visual_Direction_Lock.md` as the source of truth and return to that baseline.

## 2. Functional Chain Covered By Automated Tests

The current regression suite covers the main Phase 3 functional chain:

- Today local-first input and restart persistence
- AI reply persistence
- backend unreachable local draft and retry
- SignalCard remote read and local timeline state
- user confirmation and correction write path
- Today Summary failure not blocking SignalCard save
- AI-predicted and library-saved inclusion boundaries
- Weekly first-day / second-day / full-ready timing
- Weekly SignalCard local_date / timezone aggregation
- Weekly eligible signal rules
- Weekly one-pattern / one-experiment
- Life Experiment save / skip / feedback
- Journey first-day / second-day Seed behavior
- Journey local_date / timezone aggregation
- Journey inclusion / exclusion and evidence levels
- Energy Budget internal SignalCard foundation
- Calendar / Health abstract hint fallback and privacy boundaries
- Signal Library private actions and library_saved SignalCard
- five-tab shell navigation including Signal Library
- Me response-style preference

## 3. Commands Run

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed, no issues found |
| `flutter test` | Passed, 114 tests |
| `backend python3 -m pytest` | Passed, 29 tests |
| `git diff --check` | Clean |
| `flutter build ios --release --no-codesign` | Passed |

## 4. iOS Release Build Result

Release build command:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter build ios --release --no-codesign
```

Result:

- Xcode build completed successfully.
- Build time: 187.9 seconds.
- Output: `build/ios/iphoneos/Runner.app`
- Size: 28.1 MB.

This verifies the Flutter / Xcode release build path without codesigning. It does not replace a signed archive or TestFlight upload.

## 5. Advisory Notes

The build emitted two non-blocking advisories:

- Flutter reports that iOS plugins are Swift Packages while the project still has CocoaPods integration. This is a migration advisory and did not block analyze, test, or release build.
- Flutter reports that UIScene lifecycle support will soon be required for upcoming iOS versions. This is a future compatibility item and did not block the current release build.

## 6. Remaining Pre-Submission Items

ReleaseQA-2.8 does not claim the following are complete:

- signed Xcode Archive
- IPA upload / TestFlight refresh
- real-device TestFlight purchase
- restore purchase on real device
- Pro entitlement verification from a TestFlight purchase
- App Store submission

These remain the next release steps after this stability check.

## 7. Screenshots

No new QA screenshots were required for this round.

Keep:

- Product Review screenshots from the current visual lock
- 2.7H visual lock documentation
- this automated stability record

## 8. Conclusion

ReleaseQA-2.8 passes as a functional chain and pre-release stability check.

The app is ready for the next release operation step: signed archive / TestFlight refresh / purchase verification, depending on the chosen release path.
