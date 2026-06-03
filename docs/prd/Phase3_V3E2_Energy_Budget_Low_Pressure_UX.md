# Phase 3 V3E-2 Energy Budget Low-Pressure UX

Date: 2026-05-29

Status: Engineering implementation in progress / V3E-2.

Scope: expose V3E-1 Energy Budget Basic as a lightweight user-facing block. This round does not add Calendar, HealthKit, schedule-density analysis, a standalone Energy Budget page, or a complex dashboard.

## 1. Display Entry

Current entry:

- Weekly page, as a lightweight `Energy Budget` block.

Reason:

- Weekly is already the short-cycle operating surface.
- Energy Budget Basic is still internal-signal based, so it should appear as a small interpretation block, not a full time-management page.
- Journey can later reuse the same model for long-range energy structure.

## 2. Output Structure

The Weekly Energy Budget block shows:

- most costly source
- recovery clue
- buffer point
- small adjustment
- Life Experiment link

This mirrors `EnergyBudgetModel`:

- `mostDrainingSource`
- `recoveryClue`
- `bufferLocation`
- `switchingAdjustment`
- `experimentConnection`

## 3. Low-Pressure Copy

Do not say:

- energy management failed
- your schedule is bad
- you should be more disciplined
- completion / failure language

Use:

- "This is not a score or diagnosis."
- "这里可能有点耗力"
- "可以先给这里留一点余地"
- "这个调整也可以只是试试看"

The block should help the user see where life may be costly. It should not imply the user needs to manage themselves harder.

## 4. State And Evidence Copy

Evidence explanation shown in the block:

- older / legacy notes may be used only as light context.
- unconfirmed notes may be used only as light context.
- inaccurate, excluded, sensitive, or unsynced notes are not used.

Energy Budget is not:

- diagnosis
- score
- productivity judgement
- discipline tracker

## 5. Life Experiment Connection

When a block looks costly, the copy may connect it to a small Life Experiment.

Rules:

- experiments remain optional.
- skipped is normal.
- not_helpful is normal feedback.
- adjusted is useful learning.
- no habit-tracker framing.

## 6. Fallback

Data-insufficient state:

- show a lightweight explanation.
- do not pretend deep analysis.
- suggest recording one slightly costly or slightly lighter moment.

Aggregation failure:

- `EnergyBudgetRepository` currently uses local deterministic aggregation and local fallback.
- Energy Budget failure should not block Today, Weekly, Journey, SignalCard, or Life Experiment.
- Energy Budget loading failure must not block the Weekly page's main experience.
- Energy Budget is an added observation layer, not a precondition for Weekly.

## 7. Tests

Covered by:

- `frontend_flutter/test/features/pages/weekly/weekly_page_widget_test.dart`
- `frontend_flutter/test/core/api/repositories/energy_budget_repository_test.dart`

Test coverage:

- Energy Budget UI block appears in Weekly.
- low-pressure copy appears.
- data-insufficient fallback appears.
- evidence explanation says excluded / inaccurate / sensitive / unsynced notes are not used.
- Life Experiment suggestion copy is displayed as optional.
- repository tests cover inclusion / exclusion and Life Experiment feedback.

Commands:

- `flutter test test/features/pages/weekly/weekly_page_widget_test.dart`
- `flutter test test/core/api/repositories/energy_budget_repository_test.dart`
- `flutter analyze`
- `flutter test`

Backend pytest is not required for V3E-2 because no backend path is changed in this round.

## 8. Remaining Boundaries

Still deferred:

- complete standalone Energy Budget page
- Calendar integration
- HealthKit integration
- schedule density
- time-block chart
- Energy Budget backend sync
- release-grade manual UI screenshot / recording

Release QA blocker remains:

- Xcode / CoreSimulator / SPM issue prevents reliable simulator screenshot or recording evidence.
- do not mark manual UI evidence complete before valid simulator/device/CI screenshots or recording exist.
