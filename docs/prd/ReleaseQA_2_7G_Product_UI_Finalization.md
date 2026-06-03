# ReleaseQA-2.7G: Product UI Finalization

Status: Engineering implemented and validated.

Scope: product-facing copy, launch/onboarding polish, and Product Review screenshots only. This round does not change purchase, Pro, quota, privacy boundaries, EventKit / HealthKit integration, or Phase 3 data-chain logic.

## Product UI Rules

- Product screenshots no longer show QA / evidence / acceptance labels.
- Product UI does not expose internal timing states such as Day 0, Day 1, Weekly Lite, Journey Seed, active app days, eligible signals, or ready.
- Internal timing logic remains:
  - Local calendar day is used instead of 24-hour delay.
  - Weekly / Journey can show forming states for new users.
  - The next local day after at least one eligible signal can show lightweight product content.
  - Full Weekly still requires 7 active app days and enough eligible signals.
  - Deleting signals recomputes Weekly / Journey from the current eligible SignalCards.

## User-Facing State Language

| Internal concept | Product language |
| --- | --- |
| no signal / insufficient | 正在形成 |
| weekly light ready | 本周小观察 |
| journey seed | 第一段生活路径 |
| weekly ready | 本周小观察已形成 |
| eligible signal | 真实信号 / 可用信号 |
| unconfirmed | 还只是线索 |
| raw saved after AI failure | 原文已保存，小观察稍后再试 |

## Copy And Navigation

- Chinese bottom navigation: `今天 / 本周 / 旅程 / 信号库 / 我的`.
- Japanese bottom navigation: `今日 / 今週 / 旅路 / シグナルライブラリ / マイ`.
- English bottom navigation: `Today / Weekly / Journey / Library / Me`.
- Chinese page titles now avoid unnecessary English labels for core tabs.
- Signal terminology remains:
  - `信号 / シグナル / signal`
  - `小观察 / 小さな観察 / small observation`
  - `生活地图 / 生活の旅路 / Life Journey`

## Product Review Screenshots

Screenshots were generated in:

`/private/tmp/signalpath_product_review_2_7g/`

Included product review screens:

- `splash.png`
- `onboarding_1.png`
- `onboarding_2.png`
- `onboarding_3.png`
- `today.png`
- `weekly_forming.png`
- `weekly_small_observation.png`
- `weekly_formed.png`
- `journey_forming.png`
- `journey_first_path.png`
- `journey_life_map.png`
- `signal_library.png`
- `me.png`

The screenshots use synthetic product review data only and contain no real user raw text, audio, Calendar data, HealthKit data, QA labels, filenames, page numbers, or internal state labels.

## Validation

- `flutter analyze`: passed.
- `flutter test`: passed.
- `backend python3 -m pytest`: passed.
- `git diff --check`: clean.
