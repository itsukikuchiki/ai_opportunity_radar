# ReleaseQA-2.6 Regression Build / TestFlight Refresh

Date: 2026-05-30

Scope: regress ReleaseQA-2.5 productization changes, generate data-state evidence screenshots, build a fresh iOS release IPA, and upload a new TestFlight build. This round adds no new product feature, no UI redesign, no real EventKit / HealthKit integration, and no Phase 3 data-chain change.

## 1. Status

| Area | Result |
| --- | --- |
| Demo seed evidence | Passed |
| Frontend clean dependency baseline | Passed |
| Frontend static check | Passed |
| Frontend tests | Passed |
| Backend tests | Passed |
| Whitespace diff check | Passed |
| iOS release build | Passed |
| IPA archive/export | Passed |
| TestFlight upload | Passed |
| TestFlight distribution | Passed for Internal testers |

New QA3 baseline:

- Version / build: `3.0.0 (2)`
- Bundle ID: `jp.sunrise.signalpath`
- App Store Connect app id: `6761879857`
- TestFlight status: uploaded, processed, changelog set, distributed to Internal testers

QA3 should use `3.0.0 (2)`, not `3.0.0 (1)`.

## 2. Commands And Results

| Command | Result |
| --- | --- |
| `python3 frontend_flutter/tool/render_releaseqa_phase3_evidence.py` | Wrote 15 screenshots |
| `flutter clean` | Passed |
| `flutter pub get` | Passed |
| `flutter analyze` | No issues found |
| `flutter test` | 109 passed |
| `git diff --check` | Passed |
| `python3 -m pytest` in `backend` | 29 passed |
| `flutter build ios --release` | Built `build/ios/iphoneos/Runner.app` |
| `flutter build ipa --release` | Built `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/SignalPath.ipa` |
| `fastlane pilot upload ...` | Uploaded and distributed `3.0.0 (2)` |

Backend pytest produced deprecation warnings and pytest cache-write warnings only; all tests passed.

## 3. Evidence Screenshots

Evidence directory:

`/private/tmp/signalpath_releaseqa_phase3_productization/`

Manifest:

`/private/tmp/signalpath_releaseqa_phase3_productization/manifest.txt`

Generated screenshots:

- `01_today_signal_feed_full.png`
- `02_signal_composer_input.png`
- `03_voice_transcript_edit.png`
- `04_ai_predicted_confirm_mode.png`
- `05_library_saved_timeline_card.png`
- `06_signalcard_compact_state.png`
- `07_plan_block_local_only.png`
- `08_weekly_life_dashboard.png`
- `09_weekly_energy_stacked_bar.png`
- `10_life_experiment_feedback.png`
- `11_energy_budget_block.png`
- `12_journey_life_map.png`
- `13_journey_heatmap_review_adjust.png`
- `14_signal_library_cards.png`
- `15_library_share_preview.png`

Evidence data is synthetic only. It contains no real user raw text, no real Calendar fields, no HealthKit raw samples, and no audio.

## 4. Demo Seed Coverage

| Area | Coverage |
| --- | --- |
| Today / Signal Feed | 5 synthetic SignalCards covering text, voice, ai_predicted, library_saved, and local draft |
| Confirmation states | accurate / unconfirmed / supplemented / adjusted represented in screenshots |
| Energy load | draining / restoring / mixed / neutral represented |
| User correction | `Your context` represented as private `user_correction_json` |
| Local draft | waiting-to-sync state represented |
| Weekly | one-pattern, one-experiment, Life Experiment, Energy Budget stacked bar, Plan Block represented |
| Journey | 8-week synthetic distribution, heatmap, long-term pattern, recovery clue, Review & Adjust represented |
| Energy Budget | most costly source, recovery clue, buffer suggestion, Calendar abstract hint, Health abstract hint represented |
| Signal Library | curated pattern cards, save-to-observation, share preview represented |

## 5. Privacy / Boundary Checks

| Boundary | Result |
| --- | --- |
| Voice audio | No real microphone or speech permission is requested; transcript-only MVP stores text, not audio |
| Info.plist microphone / speech keys | Not required in this build because no native microphone / speech recognizer is used |
| Permission denied fallback | Text input remains the complete fallback path |
| `ai_predicted` inclusion | Unconfirmed AI-predicted cards do not enter Summary / Weekly / Journey / Energy Budget |
| Plan Block | Local-only via SharedPreferences; no Apple Calendar, no notification, no task |
| Charts | Wording states distribution / observation; no score or diagnosis |
| Library share | Copies/shows official abstract pattern only; no user raw text, context, or private action |
| EventKit / HealthKit | Still not truly connected; external hints remain abstract prototype context |

## 6. iOS Build Notes

Archive validation:

- Version Number: `3.0.0`
- Build Number: `2`
- Display Name: `Signal Path`
- Deployment Target: `13.0`
- Bundle Identifier: `jp.sunrise.signalpath`

Flutter still prints the Swift Package + CocoaPods integration warning:

`All plugins found for ios are Swift Packages, but your project still has CocoaPods integration.`

Observed impact:

- Did not block `flutter pub get`
- Did not block `flutter analyze`
- Did not block `flutter test`
- Did not block `flutter build ios --release`
- Did not block `flutter build ipa --release`
- Did not block TestFlight upload / distribution

## 7. TestFlight Result

Fastlane result:

- Successfully uploaded package to App Store Connect
- Successfully finished processing build `3.0.0 - 2` for iOS
- Successfully set changelog
- Export compliance set to `false`
- Successfully distributed build to Internal testers

Temporary App Store Connect API key JSON was deleted from `/private/tmp` after upload.

## 8. QA3 Entry

Purchase / Pro / quota QA can continue on TestFlight build `3.0.0 (2)`.

Still not covered by ReleaseQA-2.6:

- real-device TestFlight purchase / restore
- Pro entitlement behavior after real purchase
- quota QA on a real TestFlight install
- real EventKit permission
- real HealthKit permission
