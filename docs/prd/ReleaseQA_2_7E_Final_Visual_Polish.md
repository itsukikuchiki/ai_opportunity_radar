# ReleaseQA-2.7E Final Visual Polish

Status: Engineering implemented / ready for review

Scope: final visual polish only. This pass does not change Phase 3 business logic, data chains, privacy rules, Purchase / Pro / quota behavior, or real EventKit / HealthKit integration.

## Goals

- Close the remaining brand / launch / illustration issues before QA3.
- Remove black loading spinner risk by aligning iOS LaunchScreen and Flutter loading state.
- Unify App icon, splash, and onboarding around one soft signal-path visual language.
- Make Today / Weekly / Journey / Library / Me remain stable without large structure changes.

## Implemented Fixes

### Launch / Splash

- Changed iOS LaunchScreen background to warm ivory.
- Replaced Flutter loading spinner with a branded Signal Path launch screen.
- Regenerated LaunchImage with soft path + signal dots + micro sparkle.
- Regenerated AppIcon without `AI` text.
- Kept App icon / LaunchImage / splash in the same signal-path visual language.

### Brand Splash

- Removed decorative upper / lower placeholder bands from the product splash.
- Centered the refined signal-path mark, brand title, and tagline.
- Kept the tagline: `看见信号，轻轻调整`.

### Illustration System

- Kept illustrations based on the same Signal Illustration Kit:
  - soft path
  - signal dots
  - buffer gap
  - cluster
  - recovery cue
  - private observation container
- Today AI suggestion now uses a more compact signal-path visual instead of a large empty diagram.
- Weekly small experiment remains problem -> method -> target, but the page stays within the safe area.

### Me / Pro

- Added lightweight quota progress bars for:
  - Today AI response usage
  - Deep Weekly usage
- Kept restore purchase visually separate from quota copy.

## Boundaries Kept

- No feature logic changes.
- No Purchase / Pro / quota logic changes.
- No user raw text in Signal Library.
- No raw Calendar / HealthKit data downstream.
- No real EventKit / HealthKit integration.
- No AI-generated per-user illustrations.

## Evidence Directory

Product review screenshots should be generated under:

`/private/tmp/signalpath_releaseqa_phase3_final_visual_polish/`

## Validation

Required checks:

- `flutter analyze`
- `flutter test`
- `git diff --check`

Backend pytest is not required for this visual / asset polish pass unless backend files change.

