# ReleaseQA-2.7D UI Freeze Fix

Status: Engineering implemented / ready for review

Scope: visual freeze fixes only. This pass does not change Phase 3 business logic, data chains, privacy boundaries, Purchase / Pro / quota logic, or real EventKit / HealthKit integration.

## Goals

- Make the 2.7 visual direction feel closer to a real shipped product.
- Remove remaining showcase / evidence-harness feeling from product review screenshots.
- Improve typography softness, illustration explanation, and first-screen density.
- Keep Phase 3 privacy and evidence boundaries unchanged.

## Implemented Fixes

### Splash / Brand

- Refined the launch visual to reduce large blank areas and page-like presentation.
- Unified the visual language around signal dots, a soft path, and a small brand sparkle.
- Kept the tagline light: `看见信号，轻轻调整`.
- Did not introduce unlicensed custom fonts.

### Typography

- Reduced heavy title and body weights across the visual harness.
- Kept Chinese headings softer and less dashboard-like.
- Kept body copy readable with relaxed line height.
- Kept CTA and status chip hierarchy distinct without making all pills look identical.

### Illustration

- Preserved explanatory visuals for AI light suggestion, Weekly small experiment, Journey map, Library save flow, and sharing.
- Weekly experiment continues to show the structure: problem -> method -> target.
- Journey map now includes week markers and guide divisions so it reads as an 8-week path rather than random scatter.

### Today / Weekly Safe Area

- Reduced Today content density so the AI light suggestion is visible in the product frame.
- Reduced Weekly experiment card density while preserving the one-pattern / one-experiment structure.
- Added more internal bottom padding in the app frame content.

### Copy

- Updated Library pattern copy:
  - `有些时候，真正耗力的不是某一件事，而是频繁来回切换。`
  - `当很多事情之间没有空隙，恢复感可能会慢慢变薄。`
- Updated Pro copy:
  - `解锁更深的 Weekly、Journey、额度和轻量对话。`
- Updated quota copy:
  - `本月使用`
  - `Today AI 回应 18 / 150`
  - `Deep Weekly 1 / 4`
  - `超出后仍可继续记录`

## Boundaries Kept

- No business logic changes.
- No data-chain changes.
- No privacy-boundary changes.
- No Purchase / Pro / quota logic changes.
- No real EventKit / HealthKit integration.
- No raw user text in Signal Library.
- No raw Calendar / HealthKit data in visual output.

## Evidence Directory

Product review screenshots should be generated under:

`/private/tmp/signalpath_releaseqa_phase3_ui_freeze_fix/`

The directory should contain product-like screenshots without QA filename labels, page counters, or QA footer copy.

## Validation

Required checks:

- `flutter analyze`
- `flutter test`
- `git diff --check`

Backend pytest is not required for this visual-only pass unless backend files change.

