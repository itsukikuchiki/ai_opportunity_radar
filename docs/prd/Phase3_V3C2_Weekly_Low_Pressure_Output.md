# Phase 3 V3C-2 Weekly Low-Pressure Output

Date: 2026-05-29

Status: Engineering accepted.

## 1. Goal

V3C-2 keeps Weekly on the V3C-1 SignalCard data path and changes the output shape from “many report sections” to:

- one light weekly observation
- one most consuming pattern
- one low-cost experiment
- one positive / recovery signal

No large visual redesign was included.

## 2. Output Structure

Code paths:

- `frontend_flutter/lib/core/models/weekly_models.dart`
- `WeeklyInsightModel.deriveV3CStructure()`
- `WeeklyV3CStructureModel`
- `frontend_flutter/lib/features/pages/weekly/weekly_page.dart`
- `_WeeklyV3CStructureCard`

Rules:

- `patterns` is normalized to one item.
- `frictions` is normalized to one item.
- `bestAction` is softened into one experiment-style sentence.
- `opportunitySnapshot.summary` becomes the recovery / positive signal when available.
- Fallback copy does not pretend to know more than local stats support.

## 3. Low-Pressure Copy

Applied copy principles:

- use “这周可以先这样看”
- use “可以试试”
- avoid “必须”
- avoid “失败”
- avoid task-management framing
- avoid judging the user
- keep excluded records framed as saved Timeline material, not errors

Repository safeguard:

- `_softExperimentText()` replaces pressure words from generated output before display.
- This softening only applies to AI-generated Weekly output fields such as `bestAction`.
- It never mutates `SignalCard.raw_text`, user diary text, or any original user input.

## 4. SignalCard Inclusion User Explanation

Code paths:

- `WeeklyRepository._buildInclusionSummary()`
- `WeeklyRepository._withWeeklyMetadata()`
- `WeeklyInsightModel.inclusionSummary`
- `_WeeklyInclusionCard`

Displayed meaning:

- how many records were used in Weekly
- how many stayed only in Timeline
- how many legacy records were only treated as gentle context
- notes that are still syncing, marked not quite right, or excluded by privacy remain saved in Timeline and are not treated as Weekly analysis material

This is intentionally not phrased as an error state.

## 5. Fallback Behavior

Data paths:

- no eligible SignalCards: `insufficient_data`
- few eligible SignalCards: `light_ready`
- AI generation failure: local fallback Weekly

Fallback rules:

- local fallback uses SignalCard stats only
- local fallback keeps one pattern / one experiment
- local fallback does not claim deep interpretation
- fallback does not remove or change Today / SignalCard records

## 6. Tests

Updated files:

- `frontend_flutter/test/core/api/repositories/weekly_repository_test.dart`
- `frontend_flutter/test/features/pages/weekly/weekly_page_widget_test.dart`

Coverage:

- insufficient data state
- AI fallback state
- one-pattern normalization
- one-experiment softening
- inclusion summary metadata
- inclusion / exclusion user-facing copy
- Weekly still reads SignalCard
- draft / sync failed / inaccurate / privacy-excluded cards do not enter Weekly

Targeted results:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/core/api/repositories/weekly_repository_test.dart
flutter test test/features/pages/weekly/weekly_page_widget_test.dart
```

Results:

- repository tests: `13 passed`
- widget tests: `3 passed`

## 7. Notes

V3C-2 does not add backend Weekly endpoints and does not sync local inclusion metadata back to backend yet.

Follow-up:

- decide whether `included_in_weekly` should PATCH to backend
- make backend Weekly generation mirror frontend inclusion rules
- connect the same one-pattern / one-experiment structure to future Life Experiment storage
