# ReleaseQA-2.7F: Brand / Language / Onboarding Final Adjustments

Status: Engineering implemented and validated.

Scope: final copy and brand alignment only. This round does not change Phase 3 data chains, privacy boundaries, purchase, Pro gating, quota logic, EventKit, or HealthKit integration.

## Changes

- App Icon, native LaunchImage, Flutter Splash, and onboarding now use the same pink-coral App Icon source language.
- App Icon no longer contains `AI` text.
- Native LaunchScreen background now matches the pink-coral brand background.
- Onboarding is reduced to three pages:
  - Brand: `Signal Path` / `看见信号，轻轻调整`
  - Input: save-first private signal capture
  - Output: Weekly + Journey turning scattered signals into a life path
- Chinese bottom navigation is fully localized:
  - `今天 / 本周 / 旅程 / 信号库 / 我的`
- Multilingual terminology is aligned:
  - Chinese: `信号`
  - Japanese: `シグナル`
  - English: `signal`
  - Chinese: `小观察`
  - Japanese: `小さな観察`
  - English: `small observation`
  - Chinese: `生活地图`
  - Japanese: `生活の旅路`
  - English: `Life Journey`
- Weekly and Journey empty states now explain that lightweight reads start early:
  - D0 without signals: show forming / preparation copy
  - D1 after initial signal: Weekly Lite / Journey Seed language
- "Day 1 / second day" means the next user-local calendar day, not 24 hours after the first signal.
  - Example: if a user leaves one eligible signal late on Day 0, Weekly Lite and Journey Seed can appear when they open the app on the morning of Day 1 in their local timezone.
- Weekly readiness is now explicitly gated:
  - Day 0 with no signals: `first_day_gate`, with non-blank forming copy.
  - Day 0 with local signals: can show a lightweight read immediately.
  - Day 1 / second day with at least one saved signal from the previous day: `Weekly Lite`.
  - Before 7 active app days: remains `Weekly Lite`, even if several signals exist.
  - After 7 active app days and enough eligible signals: upgrades to full `Weekly`.
- Journey readiness is now explicitly described:
  - Day 0 with no signals: first-day gate, with non-blank forming copy.
  - Day 0 with local signals: can show a seed path immediately.
  - Day 1 / second day with at least one saved signal from the previous day: `Journey Seed`.
  - Before 8 weeks: shows Seed / Lite / partial Life Journey, not a blank page.
  - With longer history: naturally becomes the 8-week `生活の旅路` / Life Journey view.
- QA screenshot harness now uses the same App Icon source and the updated small-observation copy.

## Timing Rules

Two readiness clocks are intentionally separate:

| Rule | Trigger | Does it wait for active app days? |
| --- | --- | --- |
| Weekly Lite / Journey Seed | User-local calendar day has advanced and there is at least one previous-day eligible signal. | No. |
| Full Weekly ready | 7 active app days plus enough eligible signals. | Yes. |
| Fuller Journey / 8-week Life Journey | Accumulated long-term signal history. | No hard empty wait; it grows from Seed to richer Journey. |

`Day 0`, `Day 1`, and local grouping are always based on the user's local natural day through `local_date` / timezone-aware local dates. They are not calculated as "24 hours since first use".

## Eligible Signals

Eligible signals are the current, non-deleted SignalCards that can safely support Weekly Lite, Journey Seed, Weekly, Journey, and Energy Budget observations.

| Source / state | Counts as eligible signal? | Rule |
| --- | --- | --- |
| User text input | Yes | Counts when saved and not excluded, inaccurate, local draft, or sync failed. |
| Voice transcript | Yes | Transcript counts; audio is not saved or uploaded. |
| AI parser / reply failed but raw input saved | Yes | Save-first raw input still counts when the SignalCard is otherwise eligible. |
| AI-predicted suggestion only | No | AI suggestions are not raw user signals by themselves. |
| AI-predicted with user's edited / supplemented context | Yes | Counts only after the user adds personal context. |
| Signal Library saved pattern only | No | Official abstract pattern is not treated as user raw input. |
| Signal Library saved pattern with user's edited / supplemented context | Yes | Counts as a private personal observation, distinct from raw diary. |
| Deleted signal | No | Weekly / Journey recompute from current SignalCards and can return to Lite / Seed / insufficient states. |
| `inaccurate` | No | User rejection excludes it from analysis. |
| `local draft` / `sync failed` | No | It stays visible in Timeline but does not enter analysis until synced. |
| `do_not_analyze` / `excluded` / `sensitive` | No | Respects privacy exclusion. |

## Display Timing Acceptance Notes

| Scenario | Weekly behavior | Journey behavior | User-facing tone |
| --- | --- | --- | --- |
| New user Day 0, no saved signal | Shows a non-blank forming state. | Shows a non-blank forming state. | "Start by leaving one signal; this is forming." |
| New user Day 0, local signal exists | Can show a lightweight read immediately. | Can show a seed path immediately. | Small observation, not a full report. |
| Day 1 / second day, at least one previous-day signal | Must show `Weekly Lite`. | Must show `Journey Seed`. | Temporary read based on a small amount of evidence. |
| Before 7 active app days | Remains `Weekly Lite` even with several signals. | Continues as Journey Seed / Lite. | Avoids strong judgment. |
| 7+ active app days with enough eligible signals | Upgrades to full Weekly. | Still depends on accumulated history; can show richer Journey Lite. | Still not diagnosis or score. |
| 8-week history available | Weekly remains weekly cycle. | Can show fuller 8-week Life Journey. | Long-term path, not evaluation. |

Automated evidence:

- `weekly_repository_test.dart`
  - Day 0 no records -> `first_day_gate`.
  - Day 0 with local record -> `light_ready`.
  - Day 1 with only one previous-day signal -> `light_ready`.
  - Day 1 with multiple signals -> still `light_ready`.
  - 7 active app days + enough signals -> `ready`.
- `memory_repository_test.dart`
  - Day 0 no records -> first-day gate.
  - Day 0 with local record -> Journey content.
  - Day 1 with one previous-day signal -> Journey Seed content.

## Core Copy Table

| Surface | 中文 | 日本語 | English |
| --- | --- | --- | --- |
| Brand subtitle | 看见信号，轻轻调整 | シグナルに気づき、そっと整える | Notice the signals, adjust gently |
| Onboarding 1 title | Signal Path | Signal Path | Signal Path |
| Onboarding 1 support | 不是诊断，也不是评分。 | 診断でも、評価でもありません。 | Not a diagnosis. Not a score. |
| Onboarding 2 title | 把今天的一点信号先放下来。 | 今日の小さなシグナルを、まず残しておく。 | Put down one small signal from today. |
| Onboarding 2 subtitle | 原文会先保存，AI 只是帮你轻轻整理。 | 原文は先に保存され、AI はそっと整えるだけです。 | Your original text is saved first. AI only helps organize it gently. |
| Onboarding 2 body | 一句话、语音转写，或只是一个状态，都可以先放进私人观察。 | 一言でも、音声の文字起こしでも、ただの状態でも、まず個人の観察として残せます。 | A sentence, a voice transcript, or even just a state can be saved as a private observation. |
| Onboarding 2 AI boundary | AI 失败也不会影响保存；整理结果只是附加小观察。 | AI の整理に失敗しても保存には影響しません。結果は追加の小さな観察にすぎません。 | Even if AI fails, your saved content stays. The result is only an added small observation. |
| Onboarding 3 title | 把零散信号整理成一条生活路径。 | ばらばらのシグナルを、生活の旅路として整える。 | Turn scattered signals into a life path. |
| Onboarding 3 subtitle | 不是报告，也不是评分。只是帮你看见这段时间哪里耗力，哪里在恢复。 | レポートでも、評価でもありません。この時期にどこで消耗し、どこで回復しているかを見るためのものです。 | Not a report. Not a score. It helps you see where energy is spent and where recovery is happening. |
| Bottom nav Today | 今天 | 今日 | Today |
| Bottom nav Weekly | 本周 | 今週 | Weekly |
| Bottom nav Journey | 旅程 | 旅路 | Journey |
| Bottom nav Library | 信号库 | シグナルライブラリ | Signal Library |
| Bottom nav Me | 我的 | マイ | Me |
| Weekly Day 0 | Weekly 正在形成 | Weekly が形になり始めています | Weekly is forming |
| Weekly Day 1 | Weekly Lite 第 2 天开始展示 | Weekly Lite は 2 日目から表示されます | Weekly Lite starts on day 2 |
| Weekly Lite caveat | 基于目前少量信号的临时观察，不是完整报告。 | 今ある少量のシグナルにもとづく一時的な小さな観察で、完全なレポートではありません。 | A temporary small observation based on a few signals, not a full report. |
| Journey Day 0 | 生活地图正在形成 | 生活の旅路が形になり始めています | Your Life Journey is still forming |
| Journey Day 1 | Journey Seed 第 2 天开始展示 | Journey Seed は 2 日目から表示されます | Journey Seed starts on day 2 |
| Journey Seed caveat | 先显示第一段轻量路径，之后逐步变成生活地图。 | まず最初の軽い道すじを表示し、少しずつ生活の旅路になっていきます。 | It starts with a light first path and gradually becomes a Life Journey. |
| Signal Library title | 信号库 | シグナルライブラリ | Signal Library |
| Signal Library privacy | 这里只展示官方抽象模式，不展示用户故事或原始记录。 | ここでは公式の抽象パターンだけを表示します。ユーザーの物語や原文は表示しません。 | Official abstract patterns only. No user stories or raw notes are shown here. |
| Me summary | 管理 Pro、额度、恢复购买和数据边界。 | Pro、利用枠、購入の復元、データ境界を管理します。 | Manage Pro, usage limits, restore purchase, and data boundaries. |
| Pro summary | 解锁更深的 Weekly、Journey、额度和轻量对话。 | より深い Weekly、Journey、利用枠、軽い対話を利用できます。 | Unlock deeper Weekly, Journey, usage limits, and lightweight conversations. |
| Quota boundary | 超出后仍可继续记录。 | 上限を超えても、記録は続けられます。 | You can still keep recording after reaching the limit. |
| Privacy boundary | 信号库不使用你的原文；日历和健康线索只作为抽象辅助。 | シグナルライブラリは原文を使用しません。カレンダーと健康の手がかりは抽象的な補助としてのみ使います。 | Signal Library does not use your original text. Calendar and health hints are abstract auxiliary context only. |

## Non-Changes

- No SignalCard schema or repository behavior changes.
- No Today / Weekly / Journey / Energy Budget inclusion rule changes.
- No Signal Library privacy boundary changes.
- No purchase / restore / quota changes.
- No real Calendar or HealthKit permission integration.

## Validation

- `flutter analyze`: passed.
- `flutter test`: 109 passed.
- `git diff --check`: clean.

Note: Flutter still prints the existing Swift Package / CocoaPods migration advisory. It is not an analyzer or test failure.
