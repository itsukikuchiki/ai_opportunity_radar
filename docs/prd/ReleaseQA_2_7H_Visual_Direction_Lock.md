# ReleaseQA-2.7H: Visual Direction Lock

> **Superseded historical visual lock — 2026-07-12.** The lock below applied to
> the 2.7H release only. It is preserved as review evidence, but it no longer
> blocks the approved icon-background onboarding treatment or the Today-based
> main-tab UI standard. Use
> [`../active/main_tab_ui_standard.md`](../active/main_tab_ui_standard.md) and
> [`../active/app_design.md`](../active/app_design.md) for current work.

Status: Visual locked and archived.

Scope: lock icon, launch, onboarding, app theme, and Product Review screenshots to the original Signal Path icon visual language. This round does not change purchase, Pro, quota, privacy boundaries, EventKit / HealthKit integration, or Phase 3 data-chain logic.

Archive note: ReleaseQA-2.7H Final Fix is the current visual lock baseline. Future work should not proactively redesign the icon, primary color system, or page background direction. Allowed visual work after this point is limited to small pixel-level refinements such as spacing, alignment, button states, text overflow, and screenshot polish.

## Locked Visual Direction

The product visual baseline is now:

- white / near-white cool background
- pale blue-gray secondary surfaces
- white main cards
- pale blue-gray observation cards
- restrained near-white suggestion cards
- deep blue primary actions and primary text accents
- low-saturation blue / green / purple / gold signal dots only
- subtle gloss / soft glow around the icon language

The previous large-area pink coral, warm ivory, warm beige, orange-beige privacy cards, and warm yellow page backgrounds are no longer the product baseline.

## Icon And Splash Decision

- App icon now returns to the original icon standard instead of a redrawn line version.
- The locked icon style is a white rounded square with pale blue-gray outer glow, soft shadow, subtle inner gloss, signal path line, upper-right sparkle dots, `Signal Path`, and the original `AI` wordmark.
- AppIcon keeps the original full-square App Store icon standard.
- Native LaunchImage, Flutter splash, and onboarding brand icon use a separate transparent display asset with the same original icon style, so the white icon card keeps its glow/shadow without showing a hard outer raster boundary.
- Splash and native LaunchScreen use a white / near-white pale blue-gray background, not a full-screen pink coral background.
- Splash keeps the original icon centered with subtle cool glow and `Signal Path / 看见信号，轻轻调整`.
- Product Review / launch / onboarding display uses the transparent brand icon asset. No additional QA screenshots are required for this archive round.

## App UI Updates

- Flutter app theme now uses an explicit cool ColorScheme instead of a seed that could drift warm.
- Main app background is `#F8FBFD`.
- Main cards remain white.
- Secondary cards use pale blue-gray or white.
- Suggestion cards use very restrained near-white yellow only when needed.
- Privacy / quota / Pro surfaces use white or pale blue-gray, not orange-beige.
- Onboarding remains three pages and now uses the same icon visual language.

## Product Review Screenshots

Screenshots were generated in:

`/private/tmp/signalpath_product_review_2_7h/`

Included screens:

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

## Confirmed Non-Changes

- Purchase / Pro logic unchanged.
- Quota logic unchanged.
- Privacy boundaries unchanged.
- EventKit / HealthKit real integration unchanged.
- Phase 3 main data chain unchanged.
- Eligible signal calculation unchanged.

## Validation

- `flutter analyze`: passed.
- `flutter test`: passed.
- `backend python3 -m pytest`: passed.
- `git diff --check`: clean.
