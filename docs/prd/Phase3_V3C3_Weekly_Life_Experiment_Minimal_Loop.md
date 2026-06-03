# Phase 3 V3C-3 Weekly Life Experiment Minimal Loop

Date: 2026-05-29

Status: Engineering accepted.

## 1. Goal

V3C-3 turns Weekly’s one small experiment from display text into a lightweight local object.

This is not a habit tracker and does not add a large visual redesign.

## 2. Data Model

Local table:

- `life_experiments`

Fields:

| Field | Purpose |
| --- | --- |
| `id` | local experiment id |
| `local_user_id` | local user ownership |
| `source_week_start` | Weekly source start |
| `source_week_end` | Weekly source end |
| `title` | one-pattern title |
| `hypothesis` | why this experiment might help |
| `suggested_action` | one low-cost action |
| `linked_signal_card_ids_json` | eligible native SignalCards supporting the experiment |
| `status` | `suggested`, `saved`, `skipped`, `tried`, `not_helpful`, `adjusted` |
| `feedback_text` | optional low-pressure feedback |
| `created_at` | local creation time |
| `updated_at` | local update time |

SignalCard relation:

- `signal_cards.linked_experiment_id` is added for saved experiment linkage.
- The experiment also stores `linked_signal_card_ids_json`.

## 3. Weekly Creation Logic

Code paths:

- `LocalLifeExperimentRepository.ensureSuggested()`
- `WeeklyRepository._attachSuggestedExperiment()`
- `WeeklyInsightModel.lifeExperiment`

Rules:

- When Weekly has eligible SignalCards, it creates or reuses one `suggested` Life Experiment for that week.
- The experiment title comes from the V3C one-pattern structure.
- The suggested action comes from the V3C one-experiment structure.
- Previous experiment feedback is read as background for the next Weekly hypothesis.
- If there is no previous feedback, Weekly still generates normally.

## 4. User Actions

Code paths:

- `WeeklyRepository.saveLifeExperiment()`
- `WeeklyRepository.skipLifeExperiment()`
- `WeeklyRepository.submitLifeExperimentFeedback()`
- `WeeklyViewModel.saveExperiment()`
- `WeeklyViewModel.skipExperiment()`
- `WeeklyViewModel.submitExperimentFeedback()`
- `_LifeExperimentCard`

Supported actions:

- save
- skip / not now
- feedback: helped a little
- feedback: needs adjustment
- feedback: not helpful this time

Tone:

- no “complete / failed” framing
- skipped is not treated as a miss
- not helpful is valid feedback
- the experiment is phrased as a design to try, not a task to complete

## 5. SignalCard Linkage Rules

Linked:

- native eligible Weekly SignalCards

Not linked:

- `user_confirmation == inaccurate`
- `is_local_draft == true`
- `sync_failed == true`
- privacy-excluded cards
- legacy cards

Legacy cards can still be low-confidence Weekly context, but do not become experiment-linked evidence.

## 6. Review & Adjust Foundation

Saved experiment feedback stays in `life_experiments.feedback_text`.

Next Weekly can read the previous experiment via:

- `LocalLifeExperimentRepository.getPreviousForWeek()`

If no feedback exists, Weekly generation continues normally.

## 7. Tests

Updated files:

- `frontend_flutter/test/core/api/repositories/weekly_repository_test.dart`
- `frontend_flutter/test/features/pages/weekly/weekly_page_widget_test.dart`

Coverage:

- Weekly creates one suggested Life Experiment.
- save / skip / feedback writes status and feedback locally.
- saving links eligible SignalCards to `linked_experiment_id`.
- excluded / inaccurate / sync failed / legacy cards do not enter experiment linkage.
- experiment feedback does not mutate or remove SignalCard raw text.
- Weekly page shows the small experiment card with save / not-now actions.

Targeted results:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/core/api/repositories/weekly_repository_test.dart
flutter test test/features/pages/weekly/weekly_page_widget_test.dart
```

Results:

- repository tests: `17 passed`
- widget tests: `3 passed`

## 8. Follow-Up

V3C-3 is local-first.

Current boundary:

- Life Experiment is a local-first / local-only foundation in V3C-3.
- Backend sync and cross-device continuity are not in V3C-3 scope.
- `skipped`, `not_helpful`, and `adjusted` feedback are preserved locally and must remain available for later Review & Adjust.
- These non-positive outcomes are valid feedback about the life design, not user failure.

Follow-up decisions:

- backend API for Life Experiment sync
- server-owned experiment ids
- Journey experiment history view
- Weekly Review & Adjust wording once multiple weeks of feedback exist
