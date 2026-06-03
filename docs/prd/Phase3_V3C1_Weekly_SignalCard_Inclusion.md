# Phase 3 V3C-1 Weekly SignalCard Inclusion

Date: 2026-05-29

Status: Engineering accepted.

## 1. Current Weekly Data Source Check

Before V3C-1, frontend Weekly used:

- `WeeklyRepository.fetchCurrentWeekly()`
- `LocalCaptureRepository.listRecentSignals(limit: 500)`
- local `captures`
- `created_at.toLocal()` range filtering and chart grouping

Problem:

- Weekly still depended on the old `captures` main chain.
- Local week boundaries were derived from `created_at`, not `SignalCard.local_date`.
- V3B SignalCard inclusion fields existed, but Weekly did not own `included_in_weekly`.

V3C-1 replacement path:

- `WeeklyRepository.fetchCurrentWeekly()`
- `LocalCaptureRepository.listSignalCards(limit: 500)`
- local `signal_cards`
- filter and group by `RecentSignalModel.localDateKey()`
- build Weekly stats from SignalCard fields
- set `included_in_weekly = true` after Weekly generation for eligible native SignalCards

## 2. Weekly SignalCard Aggregation

Code path:

- `frontend_flutter/lib/core/api/repositories/weekly_repository.dart`
- `fetchCurrentWeekly()`
- `_filterSignalsForRange()`
- `_weeklyEligibleSignals()`
- `_buildWeeklyStats()`
- `_markIncludedInWeekly()`

Aggregation rules:

- The current Weekly window is the local 7-day range ending today.
- Cards enter the week by `SignalCard.local_date`, not UTC `created_at`.
- `dayCounts` and chart buckets use `local_date`.
- `created_at` is still passed as supporting metadata, but no longer owns week grouping.
- If no eligible cards exist, Weekly returns `insufficient_data` with an empty chart range.
- If a few eligible cards exist, Weekly returns `light_ready`.

## 3. Weekly Inclusion Rules

Default:

- `included_in_weekly` remains `false`.

Eligible:

- native synced SignalCards
- `user_confirmation == unconfirmed`, as light observation material
- `accurate`, `edited`, `supplemented`
- legacy SignalCards as low-confidence reference material only

Excluded:

- `user_confirmation == inaccurate`
- `is_local_draft == true`
- `sync_failed == true`
- `privacy_level == do_not_analyze`
- `privacy_level == excluded`
- `privacy_level == sensitive`

Marking rule:

- After Weekly generation or fallback succeeds, native eligible cards are marked `included_in_weekly = true`.
- Legacy cards may be sent as `weekly_confidence = legacy_reference`, but are not marked included in V3C-1.
- Draft, failed, inaccurate, and privacy-excluded cards are never marked included.

Privacy note:

- `privacy_level = private` is allowed for the user’s personal Weekly.
- Explicitly excluded privacy levels are not used for Weekly analysis.
- Shared or Signal Library analysis still must not use raw user text.

## 4. Weekly Output Tone

V3C-1 keeps the existing Weekly layout and avoids a visual redesign.

Copy rules now applied to fallback/light Weekly:

- no “failure” framing
- no judgement-report language
- focus on one most visible consuming pattern
- suggest only one small experiment direction

Example fallback direction:

- “这周可以先轻轻看一个线索...”
- “下周只试一个小实验...”

## 5. Tests

Updated file:

- `frontend_flutter/test/core/api/repositories/weekly_repository_test.dart`

Coverage:

- Weekly reads SignalCard instead of seeding old captures.
- SignalCard eligible cards are passed to Weekly AI input.
- `included_in_weekly` is marked for native eligible cards.
- `local_date` controls week boundary and `dayCounts`.
- legacy and unconfirmed cards may enter as low-confidence/light observation material.
- inaccurate cards are excluded.
- local draft cards are excluded.
- sync failed cards are excluded.
- privacy-excluded cards are excluded.
- Weekly generation failure returns fallback and does not remove the saved SignalCard.

Targeted result:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/core/api/repositories/weekly_repository_test.dart
```

Result:

- `11 passed`

## 6. Follow-Up

V3C-1 does not complete backend sync ownership for local inclusion flags.

## 7. Privacy Level Mapping

Backend current storage:

- `backend/app/models/signal_card.py` stores `privacy_level` as `String`, default `private`.
- There is no strict backend enum class yet.
- Phase 3 technical design defines the intended backend values as `private`, `analytics_eligible`, and `abstract_pattern_eligible`.

Frontend V3C-1 local cache values:

| Frontend value | Meaning | Backend compatibility |
| --- | --- | --- |
| `private` | Can be used for the user's personal Today / Weekly / Journey analysis; must not be shared as raw text | compatible with backend default |
| `analytics_eligible` | Future opt-in for aggregate analytics without raw text | compatible with Phase 3 design |
| `abstract_pattern_eligible` | Future opt-in for abstract shared pattern generation only | compatible with Phase 3 design |
| `do_not_analyze` | Local exclusion: keep in Timeline, do not use in Weekly analysis | frontend extension |
| `excluded` | Local exclusion alias, used defensively if older/local data carries this value | frontend extension |
| `sensitive` | Local exclusion alias for records that should stay out of analysis | frontend extension |

Sync compatibility:

- If a frontend-only value must be sent to backend before a strict enum exists, it can be stored as-is because the backend column is currently `String`.
- If backend later becomes strict enum, map frontend-only exclusion values to backend `private` plus metadata such as `metadata_json.analysis_excluded = true`.
- Weekly eligibility should continue to treat `do_not_analyze`, `excluded`, and `sensitive` as local-analysis exclusions even if backend normalizes them to `private`.
- Shared analysis must only use abstract pattern fields and never raw user text.

Follow-up decisions:

- whether `included_in_weekly` local changes should PATCH to backend
- whether backend Weekly generation should mirror the same eligibility rules
- how Journey should treat Weekly-included legacy references
- whether shared analytics should use only abstract patterns and never raw text
