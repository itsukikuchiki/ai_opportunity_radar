# Phase 3+ Release QA Pass Report

Date: 2026-06-16

Scope: Phase 3+ release QA using automated tests, repository-level validation, simulator launch attempts, seed/mock data coverage, fake permission paths, and privacy/data-flow checks. This pass intentionally does not add product features.

## Executive Conclusion

Engineering automated validation is mostly healthy, but Release QA is not fully closed.

- Engineering validation: Passed.
- Platform QA: Open.
- TestFlight readiness: Suitable for validation use only; not a completed QA sign-off.
- Production release readiness: No, not until remaining Release QA blockers are cleared.
- Main blocker: Simulator screenshot capture is unstable on this machine. The app launches on the iPhone 16 Plus simulator, but `xcrun simctl io ... screenshot` repeatedly fails because CoreSimulatorService / simdiskimaged becomes invalid.
- Real-device / sandbox confirmation still required: IAP monthly/yearly purchase, restore purchase, Pro entitlement, Sign in with Apple, real EventKit permission, real HealthKit permission.

Do not treat the green automated suite as production readiness. The current release candidate may move into TestFlight platform verification, but it should not be submitted as production ready until all platform blockers are closed.

## Command Results

| Check | Command | Result |
| --- | --- | --- |
| Flutter static analysis | `flutter analyze` | Passed, no issues |
| Flutter tests | `flutter test --no-pub` | Passed, 134 tests |
| Backend tests | `python3 -m pytest` | Passed, 33 tests |
| Whitespace check | `git diff --check` | Passed, clean |
| iOS simulator build/run | `flutter run -d 660B1665-C332-4912-ABB0-46EEA020EAD0` | Built and launched on iPhone 16 Plus simulator |
| Simulator screenshot | `xcrun simctl io ... screenshot` | Failed due CoreSimulatorService / simdiskimaged instability |

Known non-blocking warnings:

- Flutter reported outdated packages and the existing Swift Package Manager warning for `sign_in_with_apple`.
- Backend pytest emitted FastAPI `on_event` and `datetime.utcnow()` deprecation warnings.
- Pytest cache could not write under the sandboxed environment; test execution still passed.

## Simulator Evidence Status

Device used:

- iPhone 16 Plus, iOS 18.5
- UUID: `660B1665-C332-4912-ABB0-46EEA020EAD0`

What worked:

- App container exists for `jp.sunrise.signalpath`.
- `xcrun simctl launch ... jp.sunrise.signalpath` returned a process id.
- Flutter debug run completed build and launched.

What failed:

- Screenshot capture produced no image file.
- Error reproduced:
  - `CoreSimulatorService connection became invalid`
  - `simdiskimaged crashed or is not responding`
  - `Unable to locate device set`

Screenshot directory:

- `/private/tmp/signalpath_phase3_plus_releaseqa/screenshots`
- Current status: no usable screenshots generated in this pass.

Release QA blocker remains open for screenshot evidence.

## Seed / Scenario Coverage

| Scenario | Coverage Source | Status |
| --- | --- | --- |
| Empty User | Weekly/Journey first-day gate repository tests | Covered by automated tests; no simulator screenshot |
| Light User | Today SignalCard save-first and local draft tests | Covered by automated tests; no simulator screenshot |
| Weekly User A | Weekly repository aggregation / one-pattern / experiment tests | Covered by automated tests |
| Weekly User B | Weekly fallback / insufficient data / inclusion tests | Covered by automated tests |
| ScheduleSignal User | Phase 3+ local repository tests for schedule/title-only/time-only signal capture | Covered by automated tests |
| Goal User | Phase 3+ local repository tests for goal creation and feedback | Covered by automated tests |
| Long-term Journey User | Memory/Journey repository tests for seed, eligibility, rollback, feedback | Covered by automated tests |
| Free User | Quota/fallback tests and repository behavior | Partially covered; real IAP state not verified |
| Pro User | UI/model/quota paths partially covered by tests | Partially covered; real entitlement not verified |

## Page / Data Flow Validation

### Today

Validated by tests:

- User input is saved before AI processing.
- AI parser/reply failure does not block record persistence.
- Local draft and retry paths exist.
- SignalCard eligibility fields are respected.
- AI reply grounding tests exist to reduce off-topic fallback replies.

Still needs manual / simulator evidence:

- Keyboard behavior.
- Voice input UI and save path on a real device.
- Bottom navigation overlap in live screens.
- Dynamic Island / safe-area clipping.

### Weekly

Validated by tests:

- Weekly reads SignalCard-derived data.
- Weekly Lite / ready logic is based on local-day and eligible-signal rules.
- Inaccurate, deleted, sync failed, privacy-excluded records are excluded.
- Deleting records triggers recomputation behavior in repository tests.
- Life Experiment creation and feedback are covered.

Still needs manual / simulator evidence:

- Full visual page under data-rich seed.
- Empty / forming state.
- Chart rendering on small screens.

### Journey

Validated by tests:

- Journey reads SignalCard-derived memory data.
- Journey Seed logic does not wait for 8 weeks.
- Long-term patterns and experiment feedback are represented.
- Deletion / exclusion rules are covered.

Still needs manual / simulator evidence:

- Journey card density and long-scroll behavior.
- Heatmap / life path rendering on multiple screen sizes.

### Signal Library

Validated by tests:

- Library uses curated patterns, not user raw text.
- Save to observation creates a private `library_saved` SignalCard.
- Private actions do not create public interaction data.
- Localization paths exist.

Still needs manual / simulator evidence:

- Chinese / Japanese / English rendering in the real app.
- Share sheet flow.

### Me / Account / Backup / Delete

Validated by tests:

- Local backup bundle export/import path.
- Backend backup requires session.
- Backend account deletion removes backups and invalidates session.
- Local delete clears user data and onboarding state, so reopening behaves like a new user.

Still needs manual / real-device evidence:

- Sign in with Apple native sheet.
- Cloud backup restore UX.
- Account delete UX in App Store production-like environment.

## EventKit / HealthKit Validation

Automated/mock status:

- Calendar schedule-density repository tests cover permission denied, no-data fallback, authorized abstract hints, and no downstream raw title/location/attendees.
- Health recovery-signal repository tests cover permission denied, no-data fallback, abstract recovery hints, and no downstream raw health samples.

Remaining real-device requirements:

- Native Calendar permission prompt.
- Native HealthKit permission prompt.
- Revoked permission behavior.
- Real-device fallback after denied permissions.

## IAP / Pro / Quota Validation

Automated/mock status:

- Quota exceeded fallback does not block record saving.
- Free/Pro quota display logic has partial coverage through repository/UI tests.

Not completed in this pass:

- Monthly Pro purchase in sandbox/TestFlight.
- Yearly Pro purchase in sandbox/TestFlight.
- Restore purchase.
- Pro entitlement activation.
- Server receipt validation roundtrip.

This is a release blocker before production submission.

## Privacy / Eligibility Validation

Covered by automated tests:

- User raw text does not enter Signal Library.
- `library_saved` records remain private.
- Calendar / Health raw data are not downstreamed into shared analysis.
- Inaccurate, excluded, sensitive, sync failed, and deleted records are excluded from report evidence.
- `included_in_*` is a usage marker, not proof of confirmed or high-confidence evidence.

Still recommended:

- One manual audit pass over rendered screenshots before App Store submission.

## Blockers

1. Simulator screenshot capture fails due CoreSimulatorService / simdiskimaged instability.
2. Real IAP purchase / restore / entitlement not verified in this pass.
3. Native Sign in with Apple not verified in this pass.
4. Real EventKit and HealthKit permission flows not verified in this pass.
5. Multi-device UI screenshots are not available from this pass.

## Non-Blockers / Follow-Up

- Backend deprecation warnings should be cleaned later.
- Flutter dependency update warnings are not release blockers.
- Pytest cache write warning is sandbox-related.

## Must Confirm On Real Device

- First launch and onboarding.
- Today save, voice input, local draft, retry sync.
- Weekly Lite, Weekly ready, Journey Seed, Journey long-term view.
- IAP monthly, IAP yearly, restore purchase, Pro entitlement.
- Sign in with Apple, backup snapshot restore, account deletion.
- Calendar permission, HealthKit permission, denied/revoked fallback.
- Keyboard behavior and bottom navigation overlap.

## Recommendation

Do not mark Phase 3+ Release QA as fully passed yet. The code-level automated suite is green, but release readiness still depends on screenshot evidence and real-device platform flows.

Recommended next step:

1. Run a focused Platform QA Pass, with no new feature work.
2. Try one more CoreSimulator cleanup / fresh-device screenshot pass.
3. If simulator screenshots remain unstable, switch to TestFlight / real-device screenshots instead of spending more time on the local simulator.
4. Complete IAP / restore / Pro entitlement, Sign in with Apple, backup restore, EventKit, and HealthKit real-device confirmation.
5. Re-run the same command suite before packaging the next release candidate.
