# Phase 4 Automated Test Matrix

Status: active guardrail
Target: Signal Path 4.0.0+
Purpose: prevent obvious UI, data-chain, and interaction regressions before TestFlight.

## Why Previous Automation Missed Visible Bugs

The previous suite was healthy for repository logic and some widget smoke tests, but it did not fail on several release-visible problems:

- UI tests did not cover compact phones, large phones, and tablet widths as a matrix.
- RenderFlex overflow and off-screen hit targets were not treated as release blockers.
- Critical buttons were often checked as text presence, not tapped as real controls.
- Bottom navigation and floating controls were not checked for obstruction.
- Signal Library filters were visually present but not verified as state-changing actions.
- Secondary pages were not checked for safe-area back controls.
- Native platform flows cannot be fully closed by mocks, but their mock/provider paths were not separated clearly from real-device QA.

## Required Automated Layers

| Layer | Coverage | Examples | Required before build |
| --- | --- | --- | --- |
| Unit / model | Pure data rules | eligibility, quotas, language mapping, privacy flags | Yes |
| Repository / service | persistence and failure behavior | save-first, retry, backup snapshot, delete account | Yes |
| View model | screen state from data | inclusion, filtering, fallback, local-first state | Yes |
| Widget page | visible behavior | buttons, chips, empty/filled states, localization | Yes |
| Release UI guardrail | multi-viewport layout and hit testing | overflow, safe area, bottom nav, tappable controls | Yes |
| Platform mock | fake native providers | Calendar / HealthKit denied, unavailable, authorized hints | Yes |
| TestFlight / real device | native platform proof | IAP, Apple Sign In, EventKit, HealthKit, keyboard, screenshots | Required for Platform QA, not replaceable by automation |

## Viewport Matrix

Release UI guardrail tests must run the primary pages at:

- Compact phone: `320 x 640`
- Regular phone: `390 x 844`
- Large phone: `430 x 932`
- Tablet: `768 x 1024`

Failure conditions:

- Any Flutter render exception.
- Any RenderFlex overflow.
- Required section title outside the viewport when first rendered.
- Critical tab label or action cannot be tapped.
- Back button is outside the safe area.
- Bottom navigation obscures primary interactive content.

## Page / Section Matrix

### Today

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Signal input | local draft + SignalCard create path | text entry saves first; voice/schedule/goal/prediction buttons are visible and tappable |
| Today overview | SignalCard energy/friction/recovery aggregation | compact layout does not overflow; no fake trend line if not backed by data |
| Small observation | Today summary / fallback | AI failure does not block raw text save |
| AI predicted signal | predicted draft SignalCard | not eligible until user confirms or adds context |
| Schedule signal | ScheduleSignal | create/edit paths persist locally and do not leak raw calendar fields |
| Goal practice | Goal / GoalTaskInstance / GoalFeedback | feedback buttons remain tappable and local-first |
| Diary timeline | SignalCard list by local date | shows raw text, saved AI reply, tags, and local sync state |
| Weekly experiment | LifeExperiment feedback | occurred / not occurred / helpful remain tappable |
| Sync notice | local queue / backup state | sync action is tappable; failure does not delete content |

### Weekly

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Weekly insight | eligible SignalCards | lite state starts from local natural Day 1; no empty report page |
| Life weather | SignalCard aggregation | metric cards fit 320px compact width |
| Main drain chain | Weekly pattern generator | displayed as flow/path, not long prose |
| Energy Budget | internal signals + abstract hints | stacked bar/legend render without overflow |
| Drain sources | friction aggregation | bars fit viewport and are not clipped |
| One Weekly Focus | Weekly one-pattern | one focus only; optional wording |
| Experiment action | LifeExperiment | save/skip/feedback preserved and not framed as failure |
| Inclusion notes | SignalCard eligibility | inaccurate, sync failed, excluded do not enter analysis |

### Journey

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Long-term insight | Journey snapshot | not a long report; fallback does not claim certainty |
| Long-term patterns | SignalCard aggregation | cards fit compact width |
| Structure path | life_chain_stage / pattern flow | arrows/path render and labels do not overflow |
| Monthly life map | monthly snapshot | 2x3 map fits compact width and is not a plain list |
| Experiment tracks | LifeExperiment history | skipped/not helpful/adjusted shown as learning, not failure |
| Review & Adjust | experiment feedback + Journey snapshot | does not block Today/Weekly if generation fails |

### Signal Library

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Category chips | curated pattern metadata | chips filter real card list and remain tappable on compact screens |
| Shared signal cards | official curated patterns | no user raw text or user story appears |
| Me too / Save / Share | private local action / library_saved SignalCard | actions are private; save creates private unconfirmed SignalCard |
| Share sheet | official abstract pattern only | no personal context or raw note is included |

### Me

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Usage preferences | local preferences | navigation rows remain tappable |
| Pro / quota | entitlement + usage counters | quota visible and updates from entitlement state |
| Advanced signal settings | EventKit / HealthKit provider state | denied/unavailable/authorized states have fallback and back button inside safe area |
| Backup / restore | Apple identity + backup snapshot | mock flow covered by automation; real Apple sheet remains Platform QA |
| Delete account | local DB + cloud deletion endpoint | local data, session, backup state, onboarding state cleared |

## Secondary Pages

Automated tests should cover at least smoke/hit/safe-area checks for:

- Diary / account book.
- Signal detail / light dialogue.
- Voice transcription sheet.
- Schedule signal editor.
- Goal practice editor and feedback.
- Paywall and restore purchase UI.
- Advanced signal settings.
- Backup / restore.
- Delete account confirmation.

## Privacy Guardrails

Automation must keep these assertions active:

- `SignalCard.raw_text` never enters Signal Library.
- `library_saved` is private and unconfirmed by default.
- User corrections and “Your context” do not enter shared content.
- Calendar raw fields are not displayed or downstreamed.
- Health raw samples are not displayed or downstreamed.
- Abstract external hints cannot override user-confirmed SignalCards.
- `included_in_summary`, `included_in_weekly`, and `included_in_journey` do not mean confirmed or high-confidence evidence.

## Commands

Frontend:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter analyze
flutter test --no-pub
flutter test --no-pub test/features/release_qa/release_ui_guardrails_test.dart
git diff --check
```

Backend:

```bash
cd /Users/yangyang/ai_opportunity_radar/backend
python3 -m pytest
```

## Platform QA Boundary

Automation and simulator mocks do not close these items:

- Monthly and yearly IAP purchase sheets.
- Restore Purchase with active and inactive subscription states.
- Pro entitlement propagation from StoreKit.
- Sign in with Apple native sheet, cancel path, token exchange, and re-login.
- Cloud backup restore after deleting and reinstalling the app.
- EventKit native permission prompt and Settings revocation.
- HealthKit native permission prompt and Settings revocation.
- Real keyboard, Dynamic Island, bottom safe area, and physical-device screenshot evidence.

These must remain `Platform QA: Open` until TestFlight or real-device evidence is collected.

## Exit Criteria

Engineering validation can be marked `Passed` only when:

- Frontend analyze passes.
- Full Flutter test suite passes.
- Release UI guardrail matrix passes.
- Backend pytest passes.
- `git diff --check` is clean.
- The test matrix document is updated for any new screen, feature, or native provider.

Production readiness can be marked `Release Candidate` only when Platform QA evidence is also complete.
