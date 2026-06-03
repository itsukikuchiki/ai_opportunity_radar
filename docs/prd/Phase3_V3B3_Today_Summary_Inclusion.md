# Phase 3 V3B-3 Today Summary / SignalCard Inclusion

Date: 2026-05-29

Status: Engineering accepted.

## Scope

V3B-3 connects Today Summary to the SignalCard main data path and clarifies SignalCard inclusion rules.

This stage does not include a large Today visual redesign.

## Summary Data Source

Today Summary now uses the same SignalCard source as Today:

- When `ApiClient` is available, `TodayRepository.fetchToday()` reads `/api/v1/captures/recent`.
- Remote SignalCards are cached locally.
- Today Summary is regenerated from today's SignalCards, grouped by `local_date`.
- Summary generation failure falls back to local copy and does not affect SignalCard saving.

## Summary Eligibility Rules

Today Summary uses eligible SignalCards only:

- included:
  - native / synced SignalCards
  - unconfirmed SignalCards, as light observations only
  - edited / supplemented / accurate SignalCards
- excluded:
  - `is_legacy`
  - `is_local_draft`
  - `sync_failed`
  - `user_confirmation == inaccurate`

Important:

- `unconfirmed` is not converted into a confirmed state.
- `legacy` can appear in Timeline, but is not treated as high-confidence Summary material.
- local draft / sync failed records remain visible as raw notes, but Summary waits until they are safer to interpret.

## Inclusion Fields

Existing fields:

- `included_in_summary`
- `included_in_weekly`
- `included_in_journey`

V3B-3 behavior:

- eligible cards used by Today Summary are marked `included_in_summary = true` locally.
- ineligible cards keep `included_in_summary = false`.
- Weekly / Journey inclusion fields are displayed if provided by backend/cache, but V3B-3 does not invent those states.

## Low-Pressure Summary Copy

Today Summary title:

- English: `Today, you can look at it this way`
- Japanese: `今日はまずこう見てみる`
- Simplified Chinese: `今天可以先这样看`
- Traditional Chinese: `今天可以先這樣看`

Rules:

- avoid “you should”
- avoid completion/failure language
- keep raw note visually before AI summary
- Summary is an added observation, not a replacement for the original note

Fallback when no card is eligible yet:

- local draft / sync pending: `今天可以先这样看：原文已经保存，等同步完成后再整理也来得及。`
- legacy only: `今天可以先这样看：旧记录已经放回时间线，这里先不急着重新判断它。`
- other deferred cases: `今天可以先这样看：记录已经留下，等线索更稳一点再整理。`

## Code Paths

- Summary source and eligibility:
  - `frontend_flutter/lib/core/api/repositories/today_repository.dart`
- Local inclusion update:
  - `frontend_flutter/lib/core/local/local_capture_repository.dart`
- Today lightweight inclusion display:
  - `frontend_flutter/lib/features/pages/today/today_page.dart`

## Tests

Added / updated:

- Summary reads SignalCard and marks eligible card `included_in_summary`.
- Summary failure does not affect SignalCard saving.
- local draft is not marked `included_in_summary`.
- legacy / inaccurate are excluded from Summary.
- unconfirmed remains unconfirmed when used as light Summary material.
- Today widget displays inclusion chip (`Used today`).

Verification commands:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/core/api/repositories/today_repository_test.dart
flutter test test/features/pages/today/today_v3b_manual_evidence_test.dart
flutter analyze
flutter test
```

Results:

- targeted TodayRepository + Today evidence tests: `18 passed`
- `flutter analyze`: no issues found
- `flutter test`: `46 passed`
