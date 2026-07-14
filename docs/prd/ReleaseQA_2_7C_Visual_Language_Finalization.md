# ReleaseQA-2.7C Visual Language Finalization

> **Superseded historical visual record — 2026-07-12.** Preserve this file as
> ReleaseQA evidence only. Current product/page rules live in
> [`../active/app_design.md`](../active/app_design.md), and current
> visual density, typography, sizing, and illustration treatment live in
> [`../active/main_tab_ui_standard.md`](../active/main_tab_ui_standard.md).

Status: Engineering implemented / ready for visual review

QA3 status: Pending

## Context

ReleaseQA-2.7B improved the visual direction, but it is not accepted for QA3.

The main remaining issues were:

- splash / brand page felt too empty and placeholder-like
- too many review screenshots diluted focus
- typography still felt too hard and engineering-like
- illustration quality was too diagram-like
- Reality / Observation / Suggestion / State / Action were visually mixed
- some Simplified Chinese copy was unnatural
- Journey map did not clearly read as 8-week data change
- Me / purchase frame needed to be included before QA3

## Scope

This is a visual-language finalization pass only.

This pass does not change:

- Phase 3 data chain
- SignalCard schema or inclusion rules
- privacy boundaries
- Purchase / Pro / quota logic
- real EventKit / HealthKit integration
- backend behavior

## Screenshot Set

The main review set is now reduced to 8 product-like screenshots:

1. `00_onboarding_brand`
2. `01_onboarding_input`
3. `02_onboarding_output`
4. `03_today_real_frame`
5. `04_weekly_real_frame`
6. `05_journey_real_frame`
7. `06_library_real_frame`
8. `07_me_real_frame`

The review set should be generated without:

- QA labels
- page counters
- QA footer copy
- component showcase pages

## Visual Language System

### Reality

Used for:

- user raw input
- voice transcript text
- user context
- private saved observation

Visual rule:

- warm paper / ivory surface
- soft cream border
- pen / voice / bookmark / lock symbols
- copy uses “你留下的内容”
- no analysis, no suggestions, no conclusions

### Observation

Used for:

- AI light observation
- Weekly pattern
- Journey pattern
- Energy insight

Visual rule:

- mist blue / pale blue surface
- signal blue accent
- copy uses “这条更像……” / “这周可以先这样看……”
- no diagnosis, no “you are this kind of person”

### Suggestion

Used for:

- AI suggested signal confirmation
- Plan Block
- Life Experiment
- Review & Adjust

Visual rule:

- pale butter / soft sage surface
- compass / leaf / path / note symbols
- copy uses “可以试试……” / “也可以跳过……”
- must express problem -> method -> target when possible

### State

Used for:

- private
- not confirmed
- supplemented
- synced / waiting to sync
- saved from Signal Library

Visual rule:

- low-saturation blue-gray badge
- weak presence
- never styled like a primary action

### Action

Used for:

- save
- share
- restore purchase
- looks right
- not quite
- adjust
- add context

Visual rule:

- muted ink-blue button
- verb-led copy
- visually distinct from state badges

## Copy Changes

Updated user-facing Chinese in the visual harness:

- `从信号库保存` -> `加入我的观察`
- `你的语境` style copy -> `我的补充` / private observation copy
- `紧凑信号卡` no longer appears in the main review set
- `确认 chips` no longer appears in the main review set
- `SignalCard` is removed from product screenshot copy
- `信号库` copy now reads as official curated patterns, not community

## Brand / Onboarding

The onboarding set is reduced to 3 pages:

1. Brand / icon
2. Input layer
3. Output layer

The brand page only shows:

- Signal Path mark
- Signal Path name
- `看见信号，轻轻调整`

The input page explains save-first behavior without technical terms.

The output page explains Weekly dashboard and Journey map as life structure views, not reports or scores.

## Journey Map Rule

Journey map should read as an 8-week data path:

- horizontal movement means time
- node size means signal count / frequency
- node color means drain / recovery / experiment / stable mode
- clusters mean repeated pattern
- line movement means state change, not score
- highlighted nodes mean recently worth noticing

## Validation

Required:

```bash
cd frontend_flutter
flutter analyze
flutter test
cd ..
git diff --check
```

Backend pytest is not required for this pass because only visual harness / UI copy / documentation are changed.

## Remaining QA Boundary

ReleaseQA-2.7C is intended to be the final visual-language pass before:

```text
ReleaseQA-2.8 TestFlight refresh
ReleaseQA-3 Purchase / Pro / quota QA
```

Avoid further major UI changes before QA3 unless a release-blocking visual defect is found.
