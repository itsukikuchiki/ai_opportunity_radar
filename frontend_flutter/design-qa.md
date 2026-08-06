# Design QA — primary app pages

## Onboarding first three pages — 2026-07-29

This pass rebuilds the opening product story from the current final feature
design. It does not reuse the earlier feature-tour copy:

1. Today is introduced as the place to save one real Signal through text,
   voice, state, schedule, or Signal Library. The preview also makes the
   boundary explicit: AI prediction appears only after a real Signal is saved.
2. Weekly Review shows the actual flow from Signal facts to behavior patterns,
   experiment feedback, and user-selected next-week small experiments or goals.
3. Journey shows the current-month facts, theme changes, and gentle review,
   while Pro is limited to the historical-month and long-term view.

### Visual sources and implementation captures

- Product truth:
  `docs/active/app_design.md` and `docs/active/data_flow.md`.
- Shared page language:
  the production Today Signal constellation, Weekly connected-Signal network,
  and Journey ring/path hero assets.
- Today onboarding:
  `design_qa/onboarding_2026-07-29/01-today-390x844.png`.
- Weekly onboarding:
  `design_qa/onboarding_2026-07-29/02-weekly-390x844.png`.
- Journey onboarding:
  `design_qa/onboarding_2026-07-29/03-journey-390x844.png`.

### Comparison iterations

1. The first Today render wrapped the headline into three visually uneven
   lines. It was rewritten as the natural two-line phrase
   `今天，留下 / 一条 Signal`.
2. The first 1.3× English render overflowed the fixed outer column. The scene
   now preserves the one-screen composition at standard text sizes and gains a
   vertical scroll fallback for long translations and accessibility text.
3. All three previews were rendered again at the same `390 × 844` viewport.
   Titles, explanatory copy, preview cards, footer statements, and page
   indicators remain visible without collision or clipped words.

### Automated verification

- First-three-page render test: passed.
- Onboarding launch and interaction regression: 5 / 5 passed.
- Checked Simplified Chinese, Traditional Chinese, Japanese, and English.
- Checked 320 × 640, 390 × 844, and 430 × 932 viewports plus 1.3× text scale.
- The fourth focus-selection page and onboarding completion flow remain
  unchanged.

final result: passed

## English localized Simulator pack — 2026-08-01

This pass creates an `en-US` iPhone 16e Simulator package from the supplied
Chinese screen set while preserving the same Aurora components, information
hierarchy, seeded state, and five-tab navigation.

### Source and implementation evidence

- Supplied source visual truth:
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.02.47.png`,
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.03.50.png`,
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.14.19.png`,
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.19.30.png`,
  and `/Users/yangyang/Desktop/截屏2026-08-01 9.30.30.png`.
- English implementation captures:
  `design_qa/simulator_en_2026-08-01/SignalPath-en-demo/01_today.png`
  through `05_me.png`.
- Same-state normalized comparison evidence:
  `design_qa/simulator_en_2026-08-01/qa_comparisons/01_today_hant_en.png`
  through `05_me_hant_en.png`.
- Direct supplied-source comparisons:
  `design_qa/simulator_en_2026-08-01/qa_comparisons/01_today_source_en.png`
  through `04_journey_source_en.png`.
- Viewport and density: 390 × 844 logical points on iPhone 16e; source and
  implementation captures are both 1170 × 2532 pixels at 3×. No density or
  crop normalization was required for the five same-state comparisons.
- State: iOS 18.5, `en-US`, fixed at July 31, 2026, with the QA showcase data
  enabled. The comparison device, route, theme, and selected tab match.
- Focused-region comparisons were not required: the 3× full-view pairs keep
  all changed English titles, counters, track labels, card copy, icons, and
  navigation labels readable at inspection size.

### Comparison history and findings

1. The first English capture exposed four P2 localization issues: the
   `Experiments` bottom label was truncated, `Weekly Review` was elided, the
   Life Experiment title and metric labels competed with the hero art, and
   the Journey readiness line compressed its counts.
2. The fixes use the existing design system: the bottom labels now fit within
   their fixed slots, the Weekly title uses a locale-aware display size, the
   Experiment hero reserves less unused English trailing space and compacts
   metric internals, and Journey gives the readiness counts a dedicated line.
3. The post-fix same-state comparisons show no remaining P0, P1, or P2 issue.
   Typography remains in the established system hierarchy without clipping;
   spacing, card geometry, gradients, colors, and navigation rhythm match the
   accepted localized reference; all supplied raster art stays sharp and uses
   the same crop; icons remain from the shared icon set; and the English copy
   is coherent, complete, and consistently calls the short-form track
   `Spot Try` / `Spot Tries` against longer-term goals.

### Verification

- The installed Simulator database contains 18 Signals across 14 distinct
  record days, all with language `en` and zero non-English Signal rows.
- It contains 2 Spot Try feedback entries and 3 longer-goal feedback entries.
- 33 targeted localization, seed-data, responsive guardrail, navigation, and
  Experiment widget tests passed.
- The final default-route iOS Simulator build succeeded and launches on Today.
- Simulator screenshots contain the full five-tab navigation without overflow.

final result: passed

## Japanese simulator data pack — 2026-08-01

### Comparison target and normalization

- Source visual truth: the supplied iPhone 16e screenshots under
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.*.png`,
  with the previously accepted Traditional Chinese simulator package at
  `design_qa/simulator_zh_hant_2026-08-01/SignalPath-zh-Hant-demo/` used as the
  same-state structural baseline.
- Implementation captures:
  `design_qa/simulator_ja_2026-08-01/SignalPath-ja-demo/01_today.png` through
  `05_me.png`.
- Device and state: iPhone 16e, iOS 18.5, light appearance, `ja-JP`, fixed app
  date 2026-07-31, Today / Weekly Review / Life Experiment / Journey / Me top
  states.
- Source and implementation captures are each 1170 × 2532 px, representing a
  390 × 844 logical viewport at 3× density. No density scaling was used in the
  same-state comparisons.

### Full-view comparison evidence

- Today: `design_qa/simulator_ja_2026-08-01/qa_comparisons/01_today_hant_ja.png`.
- Weekly Review:
  `design_qa/simulator_ja_2026-08-01/qa_comparisons/02_weekly_hant_ja.png`.
- Life Experiment:
  `design_qa/simulator_ja_2026-08-01/qa_comparisons/03_life_experiment_hant_ja.png`.
- Journey:
  `design_qa/simulator_ja_2026-08-01/qa_comparisons/04_journey_hant_ja.png`.
- Me: `design_qa/simulator_ja_2026-08-01/qa_comparisons/05_me_hant_ja.png`.

The full-resolution pairs keep all primary typography, controls, illustrations,
and navigation labels readable. A separate focused crop was only needed for the
Life Experiment metric row:
`design_qa/simulator_ja_2026-08-01/qa_comparisons/03_experiment_metric_before_after.png`.

### Findings and comparison history

1. `[P2]` The first Japanese render truncated the third Life Experiment hero
   metric as `得られた…`. The localized label was shortened to the natural
   `結論あり`; the focused before/after evidence confirms the complete label in
   the same card and viewport.
2. `[P2]` Initial Japanese checks also exposed excessive width in the Weekly
   Review hero and bottom navigation. Japanese-specific title and navigation
   sizing now preserves the source hierarchy while keeping `週間レビュー` fully
   visible.
3. `[P2]` Journey summary and calendar actions were too long for their source
   slots. The final Japanese copy uses `月次サマリー完成` and `カレンダー`,
   both visible without clipping in the post-fix capture.
4. Post-fix review found no remaining actionable P0, P1, or P2 mismatch.

### Required fidelity surfaces

- Fonts and typography: Apple system Japanese fallback, weight hierarchy, line
  height, wrapping, and optical scale remain consistent with the accepted
  baseline; no visible Japanese label is truncated.
- Spacing and layout rhythm: card bounds, margins, hero proportions, floating
  navigation clearance, radii, and vertical rhythm remain aligned across all
  five states. Natural Japanese wrapping does not overlap adjacent controls.
- Colors and visual tokens: gradients, semantic purple/mint/amber states,
  borders, and foreground contrast match the accepted baseline.
- Image quality and asset fidelity: the original Aurora hero art, focus-domain
  art, icons, avatar, masks, and crops are reused at native screenshot density;
  no placeholder or code-drawn replacement was introduced.
- Copy and content: visible app copy is Japanese, `スポットトライ` is used for the
  short-form experiment track, and seeded Signal content contains Japanese
  rather than Chinese fallback text.

### Interaction and data verification

- All five bottom-navigation items were tapped in the running simulator and
  reached the correct selected state.
- The simulator database contains 18 Japanese Signal records across 14 dates,
  two spot-try feedback records, and three experiment/goal feedback records.
- The weekly slice contains focus counts 6 / 2 / 1 and energy counts 1 / 3 / 5.
- 23 targeted seeder, shell-navigation, release guardrail, compact-phone,
  VoiceOver, and Japanese 1.3× text-scale tests passed.
- The final Japanese iOS Simulator build completed successfully.

### Follow-up polish

- `[P3, accepted]` Status-bar clock values differ from the supplied reference
  captures because they are simulator-owned chrome, not app content.

final result: passed

## Traditional Chinese simulator data package — 2026-08-01

### Source visual truth and implementation captures

- Source Today:
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.02.47.png`.
- Source Weekly:
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.03.50.png`.
- Source Life Experiment:
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.14.19.png`.
- Source Journey:
  `/Users/yangyang/Desktop/Simulator Screenshot - iPhone 16e - 2026-08-01 at 09.19.30.png`.
- Source Me:
  `/Users/yangyang/Desktop/截屏2026-08-01 9.30.30.png`.
- Traditional Chinese implementation captures:
  `design_qa/simulator_zh_hant_2026-08-01/SignalPath-zh-Hant-demo/01_today.png`,
  `02_weekly.png`, `03_life_experiment.png`, `04_journey.png`, and
  `05_me.png`.

All source and implementation captures use the same iPhone 16e viewport:
`390 × 844 pt`, `1170 × 2532 px`, `@3x`. The implementation state is
`zh-Hant-TW`, light appearance, with the showcase clock fixed at
`2026-07-31 13:30`.

### Required fidelity surfaces

- Fonts and typography: the implementation preserves the source CJK hierarchy,
  weights, line heights, and wrapping. Traditional glyphs remain legible and no
  heading, metric, or navigation label is clipped.
- Spacing and layout rhythm: card widths, radii, internal padding, and section
  spacing match the supplied page states. All five pages retain the floating
  five-tab navigation without the previously reported bottom gaps.
- Colors and visual tokens: the pearl, lavender, ice-blue, mint, apricot, navy,
  and violet tokens remain unchanged from the references, including selected
  tab and status treatments.
- Image quality and asset fidelity: supplied production hero and illustration
  assets remain sharp at `@3x`; no placeholder, duplicated device chrome, or
  missing asset is visible.
- Copy and content: visible text is Traditional Chinese. The short-form track is
  `簡單嘗試`, Weekly shows `9` Signals over `5` record days, Life Experiment
  shows `2 / 5 / 0`, and Journey shows `18 / 14 / 2 / 3`.

### Full-view and focused comparison evidence

Each source and implementation pair was opened together at original pixel
density and reviewed in one comparison input. The views preserve the same
composition and state; Weekly differs only by intentional scroll position.
Separate crops were unnecessary because the original `@3x` captures make the
key copy, metrics, icons, and navigation labels readable at full resolution.

The Journey header retains the reference's compact ellipsis after the record-day
summary. This is an accepted P3 copy-density detail, not a regression. No
actionable P0, P1, or P2 mismatch remains.

### Comparison history and verification

1. Earlier passes corrected missing persistent navigation, excessive bottom and
   hero spacing, the obsolete `10分鐘以內` label, unfinished-month Journey Pro
   exposure, and non-canonical `其他線索` fallback themes.
2. The final iPhone 16e captures were taken after those fixes from the packaged
   simulator build and compared again at the same viewport.
3. Simulator defaults report `AppleLanguages = (zh-Hant-TW)` and
   `AppleLocale = zh-Hant_TW`.
4. The installed showcase database contains `18` Traditional Chinese Signals
   over `14` days (`2026-07-18` through `2026-07-31`), `2` simple-try feedback
   events, and `3` long-form experiment feedback events. The active week uses
   canonical focus domains only: `6` emotional stability, `2` food and sleep,
   and `1` growth plan.
5. Static analysis passed with no issues. The focused showcase, Weekly,
   action-preference, Journey, and Today regression suite passed `91 / 91`, and
   the Journey nine-domain taxonomy test passed.
6. The simulator archive integrity check passed, and the package starts from
   Today without a forced QA route.

final result: passed

## Today handoff and Life Experiment track switch — 2026-07-29

This pass fixes the navigation context when Today opens all experiments and
replaces the isolated direction arrow with a complete two-track control.

### Source and implementation evidence

- Reported source:
  `/Users/yangyang/Pictures/照片图库.photoslibrary/resources/renders/3/35D4C552-8916-48AA-B977-6C48860D115A_1_201_a.jpeg`
  (1290 × 2796 px).
- Updated Life Experiment switch:
  `design_qa/experiment-track-switch-390x844-2026-07-29.png`
  (390 × 844 logical viewport; 780 × 1688 px capture).
- Same-viewport source versus implementation:
  `design_qa/comparison-experiment-track-switch-source-vs-implementation-2026-07-29.png`.

### Findings and corrections

1. A Today-originated imperative route previously left the selected bottom tab
   derived from the root URI. Selection now follows the visible leaf route, so
   opening all experiments highlights `生活小实验` while retaining the normal
   back stack.
2. The one-sided arrow was replaced with a connected two-segment switch.
   `小实验 / 简单尝试` and `目标 / 中长期` remain visible together, use the
   established mint and purple type colors, and have a clear selected surface.
3. Both segments are at least 58 pt high, support direct taps and horizontal
   swipes, and expose localized selected-state and action hints to VoiceOver.
4. The same-viewport comparison confirms a stronger grouping, clearer
   bidirectional affordance, and no remaining floating-arrow imbalance.

### Automated verification

- 28 / 28 shell, Life Experiment, localization, responsive-layout, touch-area,
  and VoiceOver regression tests passed.
- The populated 390 × 844 design render passed.
- Static analysis passed with no issues.
- No compile, archive, or TestFlight build was performed, as requested.

final result: passed

Date: 2026-07-13
Device: iPhone 16 Pro Max simulator, iOS 18.5
Viewport: 440 × 956 pt (@3x; 1320 × 2868 px)
Locale/state: Simplified Chinese, onboarding complete, fresh local account

## Visual sources

- Today: `/Users/yangyang/.codex/generated_images/019f496f-3868-7391-9dab-5fd20a5ab663/exec-6b4561b4-a1df-4f7a-b0af-1f38d1058668.png`
- Weekly: `/Users/yangyang/.codex/generated_images/019f496f-3868-7391-9dab-5fd20a5ab663/exec-4ba66da8-624f-44aa-bb73-c23431d3f71b.png`
- Experiment: `/Users/yangyang/.codex/generated_images/019f496f-3868-7391-9dab-5fd20a5ab663/exec-eacef1bd-deff-4ddf-bfde-a42cbcbff43a.png`
- Journey: `/Users/yangyang/.codex/generated_images/019f496f-3868-7391-9dab-5fd20a5ab663/exec-72d1f090-a394-49c2-bb29-40f451b63b44.png`
- Me: `/Users/yangyang/Pictures/照片图库.photoslibrary/resources/renders/B/B4E1951D-B75F-41B5-BFD3-6132EC8B8EB5_1_201_a.jpeg`

## Implementation captures

- Today empty state: `design_qa/today-empty-iphone16promax.png`
- Weekly 0/3 gate: `design_qa/weekly-empty-iphone16promax.png`
- Experiment empty archive: `design_qa/experiment-empty-iphone16promax.png`
- Journey 0/7 and Pro 0/14 gate: `design_qa/journey-empty-iphone16promax.png`
- Me profile and settings: `design_qa/me-iphone16promax.png`

## Comparison iterations

1. Matched the shared visual system across all four pages: warm pearl-to-lavender/ice-blue background, navy type hierarchy, translucent cards, blue-violet actions, compact five-tab navigation, 20–24 pt card radii, and restrained shadows.
2. Rebuilt Today around the approved order: compact day summary, quick record, AI prediction, combined “今日尝试”, then timeline. Empty action/experiment states preserve the 3-signal gate.
3. Reordered Weekly to match the approved information hierarchy and added the explicit 3-signal report/candidate gate.
4. Rebuilt Experiment around adopted experiments, status filtering, seven-day progress, upcoming experiments, and archive summary; the fresh-account state is intentionally different from the populated visual source.
5. Rebuilt Journey with the road hero, Free 7/3 readiness, factual monthly views, a three-natural-month Pro comparison, and an explicit forming state.
6. Fixed responsive issues found during QA:
   - Weekly long domain labels and evidence action at 320 pt / large text.
   - Experiment archive labels and metric cards at compact widths.
   - Journey evidence chips/action row in English at phone widths.
   - Release matrix scrolling for lazily built Weekly sections.
7. Brought Me into the same system while preserving its profile and preference behavior:
   - Kept the compact avatar hero, life-direction card, and shared onboarding focus preferences.
   - Replaced the misleading default quota with real API-backed usage only and added explicit Pro loading, active, and verification-pending states.
   - Added the existing structured self-review and advanced-signal routes, surfaced the saved AI response style, and replaced the unsupported encryption claim with a verifiable privacy-policy entry.
   - Added selected semantics/checkmarks and a responsive two-column fallback to the focus-area editor.

## Verification

- `flutter analyze`: passed with no issues.
- Primary-page, candidate, multilingual prediction, and release guardrail tests: 62 passed; Me/navigation-focused regression: 17 passed.
- Release render matrix: 320 × 640, 390 × 844, 430 × 932, and 768 × 1024 passed without overflow.
- Simulator comparison: all five primary pages checked against their respective source image and the shared Today visual system.

The source images show populated report states, while the simulator captures use a fresh account to verify the required no-data/readiness states. Populated states are covered by widget fixtures and interaction tests.

final result: passed

## Today small-experiment and goal progress — 2026-07-27

This pass verifies the confirmed Today behavior: a small experiment uses real
attempt events rather than a fixed seven-day denominator, while a goal keeps
its daily progress grid. Both use the same visible `已完成／未完成` feedback
language, and the small-experiment completion path collects its required
effect and effort feedback inline instead of opening a bottom sheet.

### Source visual truth and implementation evidence

- Source visual truth:
  `/tmp/codex-remote-attachments/019f496f-3868-7391-9dab-5fd20a5ab663/A97F8245-C7EE-47BC-AE81-7275CC17ABC8/1-照片-1.jpg`
  (`590 × 1280 px`, device screenshot).
- Focused implementation, resting state:
  `design_qa/today-attempts-focused-390x844-2026-07-27.png`
  (`780 × 1688 px`).
- Focused implementation, small-experiment completion form expanded:
  `design_qa/today-small-experiment-feedback-390x844-2026-07-27.png`
  (`780 × 1688 px`).
- Same-input full-view comparison:
  `design_qa/comparison-today-attempts-source-vs-implementation-2026-07-27.png`
  (`1560 × 1688 px`).

The implementation was rendered at a `390 × 844` logical viewport, widget
device pixel ratio `1`, and captured at `2×`. For the combined comparison, the
source screenshot was normalized to `780 × 1688 px` with Lanczos scaling and
placed beside the implementation. The source includes the preceding timeline,
success banner, and production navigation, while the implementation capture is
deliberately focused on the Today-attempt card and uses a deterministic
navigation fixture. Fidelity judgments therefore use the shared card region;
the expanded inline form is a new requested state with no earlier source
capture.

State: Simplified Chinese, light appearance, one small experiment with three
real attempt events (`2` completed, `1` not completed), one goal with seven
daily cells (`4` completed), and the small-experiment completion form expanded.

### Required fidelity surfaces

- Fonts and typography: the focused render uses the app's CJK design-review
  font and production weight/line-height hierarchy. Titles, descriptions,
  counters, and buttons remain readable without truncation or mid-word wraps.
- Spacing and layout rhythm: small experiment and goal now share the same
  title/counter/progress/feedback rhythm. Real small-experiment attempts use
  three square event cells; the goal retains seven evenly distributed daily
  cells. The inline form scrolls into view without covering the goal or fixed
  bottom navigation.
- Colors and visual tokens: mint communicates completed, apricot communicates
  not completed, lavender communicates goal status, and empty goal cells remain
  neutral. The section divider now uses `AuroraColors.line` rather than a harsh
  dark default.
- Image quality and asset fidelity: this focused region contains no raster
  illustration or non-standard image asset. Material icons use the same
  semantic size and color family as the source.
- Copy and content: `完成 2 / 登记 3` distinguishes successful attempts from
  all real attempts; the goal keeps `已完成 4 天`. Both expose `已完成／未完成`.
  Completed small experiments additionally ask `当下有帮助吗？` and
  `做起来费力吗？`, preserving the product's evaluation criteria.
- Accessibility and controls: visible feedback choices and save/cancel actions
  meet the existing minimum mobile target sizing. Progress cells carry
  per-attempt or per-date semantics. The focused regression confirms the save
  action stays above the persistent bottom navigation.

### Comparison history

1. The first focused render confirmed the new information architecture and
   interaction but exposed one P2 visual mismatch: the divider between small
   experiment and goal rendered as a dark line, unlike the quiet separator in
   the supplied screenshot.
2. The divider was changed to the production Aurora line token and the exact
   two states were rerendered at the same viewport.
3. The revised same-input comparison shows the requested shared visual grammar,
   understandable real-attempt progress, daily goal progress, and no bottom
   navigation obstruction. No actionable P0, P1, or P2 finding remains.

Focused regions were required because the effect/effort options, progress-cell
states, counter language, divider treatment, and bottom-navigation clearance
are not readable enough in the larger Today-page capture.

### Interaction and automated verification

- Expanded `已完成` for the small experiment and verified the inline
  effect/effort/note/save state.
- Scrolled to the save action and asserted its bottom edge remains at or above
  the persistent navigation's top edge.
- Verified the resting state contains three real small-experiment events and a
  seven-cell goal projection.
- `flutter test --no-pub
  test/design_qa/render_today_attempt_feedback_test.dart`: passed (`1 / 1`).
- Targeted Flutter analysis of the focused render test: no issues found.
- No overflow or uncaught widget exception was observed.

final result: passed

## 2026-07-17 — Life Experiment lifecycle charts and decision-state QA

### Scope and visual truth

- The user-supplied version-13 capture remains the source comparison:
  `/Users/yangyang/Pictures/照片图库.photoslibrary/resources/renders/6/66BCF6F2-F576-4464-8B25-05C73B1A9469_1_201_a.jpeg`.
- The revised populated render is
  `design_qa/experiment-current-2026-07-17.png`.
- The same-input side-by-side audit is
  `design_qa/comparison-life-experiment-lifecycle-charts-2026-07-17.png`.

### Findings and corrections

1. The five-state tab strip and tab-specific empty card duplicated Today's
   progress surfaces and hid the difference between an immediate small try and
   a multi-day goal. They were replaced by two simultaneous visual models: a
   three-lane branching lifecycle for small tries and a seven-day timeline
   matrix for goals.
2. Search now appears immediately below the semantic branching hero and
   filters adopted and considering items across both object types.
3. Every branch node and timeline row is a semantic button that opens its own
   detail. Candidate details expose the two decisions `采纳` and `考虑／观察`;
   adopted details separate today's completion feedback from explicit
   lifecycle completion.
4. Same-input inspection found two responsive P2 issues: long status pills and
   four-column detail metrics. Status labels now truncate inside a bounded
   pill, and metrics use a compact icon-value-label stack. No overflow remains
   at 320 pt width or 1.3× text.
5. The revised visual keeps the approved pearl branching artwork, Aurora
   palette, lighter Today typography, clear reading order, and distinct mint
   small-try / purple goal semantics. No actionable P0, P1, or P2 issue remains.

### Automated verification

- Life Experiment render test: 1 / 1 passed.
- Serial Flutter lifecycle regression: 76 / 76 passed across the main page,
  candidate decisions, repositories, migration fixtures, and backup roundtrip.
- Backend candidate-decision migration/schema tests: 9 / 9 passed.
- Targeted Flutter static analysis: 14 files, no issues found.
- No compile, archive, or TestFlight build was performed in this pass.

final result: passed

## Today refinement — 2026-07-15

Reference set: eight approved Today and secondary-page mockups supplied on
2026-07-15, covering Today, voice, state, diary timeline, Signal Library,
AI chat, candidate selection, and experiment progress.

Implementation capture:

- `design_qa/today-refined-2026-07-15-iphone16promax.png`

Comparison adjustments:

1. Kept the existing page content, ordering, interactions, and data flow.
2. Rebalanced the shared background to a warm pearl, lavender, and ice-blue
   atmosphere with soft ribbons and white-correct transparent glows; this
   removes the gray halo previously caused by transparent-black gradients.
3. Replaced the heavy headline treatment with system-font, medium-heavy
   gradient hero titles and lighter body typography.
4. Refined cards to a softer layered-glass surface with white borders,
   restrained chromatic shadows, and clearer separation from the background.
5. Added a reusable app-icon hero emblem and gradient section icon treatment
   across Today, voice/state entry surfaces, diary timeline, Signal Library,
   AI chat, and candidate pages.
6. Checked the live Today empty state on an iPhone 16 Pro Max simulator. The
   title, hero emblem, cards, and fixed bottom navigation do not overlap; the
   lower content remains scrollable above the navigation safe area.

Verification:

- `flutter analyze`: passed with no issues.
- Full Flutter regression suite: 390 passed.
- The release UI guardrail was updated to scroll to the lazy-built Today
  "View all" action at 320 pt and to use the final Simplified Chinese
  “生活小实验” terminology; its 11 viewport/language checks pass.
- Existing widget coverage exercises the affected pages at 390 × 844; live
  simulator capture was checked at 440 × 956 pt.

final result: passed

## Cross-page refinement and QA showcase candidate — 2026-07-15

This pass keeps the current information architecture, content, interactions,
and data flow unchanged. It applies the approved Today visual system to the
remaining primary and secondary pages, then verifies the isolated QA showcase
fixture used for the TestFlight candidate.

### Source visual truth

- Shared visual-system reference:
  `design_qa/today-refined-2026-07-15-iphone16promax.png`
- Per-page content and composition references remain the five visual sources
  listed at the top of this report. The Today reference governs background,
  typography weight, color balance, icon treatment, card surfaces, and spacing;
  the per-page references govern page-specific hierarchy and content.

### Viewports and state

- Responsive baseline: 390 × 844 pt, Simplified Chinese, 1.0× and 1.3× text
  scale, minimum 44 pt interactive targets.
- Live comparison device: iPhone 16 Pro Max simulator, iOS 18.5,
  440 × 956 pt (@3x; 1320 × 2868 px).
- Live state: Simplified Chinese, onboarding complete, isolated
  `qa_demo_` showcase namespace with populated Today, Weekly, Journey,
  life-experiment, and Pro-preview data.

### Implementation captures

- Today populated showcase, responsive baseline:
  `design_qa/today-qa-showcase-2026-07-15-390x844.png`
- Today populated showcase, live simulator:
  `design_qa/today-qa-showcase-2026-07-15-iphone16promax.png`
- Weekly populated showcase, live simulator:
  `design_qa/weekly-qa-showcase-2026-07-15-iphone16promax.png`
- Journey populated showcase:
  `design_qa/journey-qa-showcase-2026-07-15-iphone16promax.png`
- Journey Pro / 深度分析 populated showcase:
  `design_qa/journey-pro-qa-showcase-2026-07-15-iphone16promax.png`
- Life-experiment showcase:
  `design_qa/experiment-qa-showcase-2026-07-15-iphone16promax.png`
- Me showcase:
  `design_qa/me-qa-showcase-2026-07-15-iphone16promax.png`
- Representative refined secondary pages:
  `design_qa/action-candidates-qa-showcase-2026-07-15-iphone16promax.png`
  and
  `design_qa/weekly-deep-qa-showcase-2026-07-15-iphone16promax.png`.

### Required fidelity surfaces

- Fonts and typography: implementation uses the lighter Today hierarchy and
  system-font fallbacks. The Weekly deep-read hero was reduced from oversized
  bold display copy to a 16 pt / 600-weight readable report hierarchy, and its
  narrow-width topics now use full-width cards without mid-word ellipsis.
- Spacing and layout rhythm: 390 × 844 widget coverage and the existing Today
  and all seven live comparison captures show safe-area clearance, compact
  cards, and scrollable content above fixed navigation. The life-experiment
  filters use a responsive 3+2 layout on phones instead of clipping the fifth
  status.
- Colors and visual tokens: the implementation uses the shared warm pearl,
  lavender, ice-blue, navy, and blue-violet token system on every captured
  primary and secondary route.
- Image quality and asset fidelity: visible shared app-icon artwork remains a
  real raster asset and uses the approved crop/treatment. It remains sharp and
  consistently masked in all route captures.
- Copy and content: the QA fixture exposes real populated report states while
  preserving the final Simplified Chinese product terminology. Display-layer
  localization now prevents raw `work`, `emotional`, `starting`, `small_start`,
  `tension`, and legacy `L3 Reflect` tokens from leaking into reports while
  retaining approved `Pro`, `AI`, `Signal Path`, and `Signal Card` terms.

### Full-view and focused comparison evidence

- Full-view comparisons place the Today visual-system reference and each live
  implementation in one normalized 440 × 956 comparison input:
  `design_qa/comparison-today-vs-weekly-qa-showcase-2026-07-15-iphone16promax.png`,
  `design_qa/comparison-today-vs-journey-qa-showcase-2026-07-15-iphone16promax.png`,
  `design_qa/comparison-today-vs-journey-pro-qa-showcase-2026-07-15-iphone16promax.png`,
  `design_qa/comparison-today-vs-experiment-qa-showcase-2026-07-15-iphone16promax.png`,
  `design_qa/comparison-today-vs-me-qa-showcase-2026-07-15-iphone16promax.png`,
  `design_qa/comparison-today-vs-action-candidates-qa-showcase-2026-07-15-iphone16promax.png`,
  and
  `design_qa/comparison-today-vs-weekly-deep-qa-showcase-2026-07-15-iphone16promax.png`.
- Focused hero, report-card, progress-control, and bottom-navigation crops are
  combined in
  `design_qa/comparison-focused-cross-page-2026-07-15.png`.

### Comparison history and current findings

1. Automated and live checks established the shared Today background, glass
   surfaces, typography, icon language, and safe-area behavior.
2. Same-input comparisons found and closed the life-experiment filter overflow,
   Weekly deep-read heavy typography and truncated cards, and raw internal
   taxonomy labels in Weekly, Journey, Energy Budget, and Pro copy.
3. Final normalized comparisons show no remaining P0, P1, or P2 fidelity issue.
   No P3 item is required for this TestFlight showcase candidate.

### Automated verification

- `flutter analyze`: passed with no issues.
- Full Flutter regression suite: 422 passed.
- Backend regression suite: 89 passed, 2 skipped (PostgreSQL-only checks).

final result: passed

## Today signal-recording header refinement — 2026-07-16

This pass implements the four requested Today refinements without changing the
page workflow: remove the redundant summary label, replace the detached app
icon with an integrated signal-path visual, express Energy / Friction /
Recovery as qualitative user states, and keep text entry as the default by
removing the redundant Text shortcut.

### Source and implementation evidence

- User-supplied source state:
  `/tmp/codex-remote-attachments/019f496f-3868-7391-9dab-5fd20a5ab663/D6CD0F45-D5E0-44CA-8B1D-3CD283778B21/1-照片-1.jpg`
- Live implementation capture:
  `design_qa/today-signal-header-2026-07-16-iphone16promax.png`
- Full-view same-input comparison:
  `design_qa/comparison-today-source-vs-signal-header-2026-07-16.png`
- Focused header and input comparison:
  `design_qa/comparison-today-source-vs-signal-header-top-2026-07-16.png`

### Viewport and state

- iPhone 16 Pro Max simulator, iOS 18.5, 440 × 956 pt
  (@3x; 1320 × 2868 px).
- Simplified Chinese, onboarding complete, isolated QA showcase data.
- The populated state intentionally exercises an unknown Energy state,
  elevated Friction state, and average Recovery state to confirm neutral,
  non-medical wording.

### Required fidelity surfaces

- Typography and hierarchy: the Today title, date, insight, and three state
  chips now read as one compact header. The removed label no longer competes
  with the actual daily insight.
- Image and background fidelity: the square app-icon treatment is gone. A real
  raster signal-path asset is softly cropped into the header background, so it
  reads as the visual language of signal recording rather than a separate app
  badge.
- State semantics: the header no longer exposes clue counts. It uses
  qualitative labels such as `待观察`, `较足`, `偏低`, `中等`, `需留意`, and
  `一般`, while keeping empty/uncertain evidence neutral.
- Default text entry: the text field and submit control remain the default
  recording path. The shortcut row now contains only Voice, State, Plan, and
  Signal Library, each retaining a minimum 44 pt target and semantic label.
- Layout and spacing: the four actions distribute evenly at phone width; no
  overflow, overlap, clipped copy, or unsafe-area collision is visible.

### Comparison history and findings

1. The supplied source and live implementation were normalized to the same
   phone aspect ratio and combined into one comparison input.
2. The comparison confirms the requested label and Text shortcut are absent,
   the header artwork is integrated, and the three state chips no longer show
   clue counts.
3. `需留意` is used instead of literal `危险` because these states are
   heuristic wellbeing cues rather than a medical-risk determination.
4. Final full and focused comparisons show no remaining P0, P1, or P2 visual
   issue.

### Automated verification

- Focused Today, manual-evidence, and release UI guardrail tests: 48 passed.
- Full Flutter regression suite: 425 passed.
- `flutter analyze`: passed with no issues.

final result: passed

## Journey monthly and three-month correction — 2026-07-22

This section supersedes the earlier Journey evidence-list and
synthetic-life-curve QA baselines. Those older captures remain historical
implementation records only and must not be used as current acceptance truth.

Current visual/data acceptance order:

1. selected natural month and a functional historical-month switcher;
2. a Signal-only monthly path (no Weekly behavior-pattern card and no
   small-experiment round review in this lane);
3. selected-month facts and exact `7 eligible Signal / 3 local dates`
   synthesis readiness;
4. a separate small-experiment and goal trajectory using real attempt,
   progress, weekly-review, and whole-round-review events;
5. state and rhythm from real daily Signal counts, the canonical five energy
   states, and actual small-experiment feedback markers;
6. monthly theme and monthly lookback only after readiness;
7. Pro three-natural-month change for the selected month and its two preceding
   months.

Below readiness, owned facts and trajectories remain visible. The Pro page
does not repeat the experiment/goal trajectory and contains no analysis-scope,
source-Signal list, date drill-down, or AI chat section. Journey and Today must
open the same canonical diary page with the selected local date applied.

New comparison captures must be produced only after the data projection,
historical navigation, and three-month Pro widget tests pass; screenshots are
not allowed to stand in for those behavior checks.

## Unified icon-quality page illustration system — 2026-07-17

This pass establishes one semantic illustration system across the four core
routes and their representative secondary pages without changing content,
functions, navigation rules, persistence, or generation data flow:

- Today: independent scattered Signal points.
- Weekly: the same Signal points connected into review relationships.
- Life Experiment: Signal points opening into multiple possible paths to show
  change and expansion.
- Journey: a luminous ring becoming a continuous long-term path.

The user explicitly requested no build in this pass. Verification therefore
uses rendered Flutter captures, same-input visual comparisons, widget tests,
and targeted static analysis.

### Source visual truth and implemented assets

- Today:
  `/Users/yangyang/.codex/generated_images/019f6ef7-802d-7413-be56-0405dfff3d65/exec-f239827c-0849-44aa-9bb9-2e9618991327.png`
  → `assets/hero_art/today-signal-points-v1.png`.
- Weekly:
  `/Users/yangyang/.codex/generated_images/019f6eb1-c3ef-7cd1-9f6c-6c791be5c1d5/exec-d09d6620-dab8-40fb-a494-963b84136d7f.png`
  → `assets/hero_art/weekly-review-network-v1.png`.
- Life Experiment:
  `/Users/yangyang/.codex/generated_images/019f496f-3868-7391-9dab-5fd20a5ab663/exec-62ef5d0f-41da-489d-8c93-5623bc98dc16.png`
  → `assets/experiment/life-experiment-branching-v2.png`.
- Journey:
  `/Users/yangyang/.codex/generated_images/019f6f14-f1a4-7972-ab55-c1c5cc2c2e10/exec-e29cae43-45f8-4e58-a9de-02122de95959.png`
  → `assets/hero_art/journey-ring-path-v1.png`.

All are real 1536 × 1024 ImageGen raster assets using the app icon's
pearl-glass material and warm cream, lavender, periwinkle, mint, cyan, and
apricot palette; no code-drawn or placeholder illustration is used.

### Implementation screenshots, viewport, and state

- Main routes, 430 × 932 pt at 2×:
  `design_qa/today-current-2026-07-17.png`,
  `design_qa/weekly-current-2026-07-17.png`,
  `design_qa/experiment-current-2026-07-17.png`, and
  `design_qa/journey-current-2026-07-17.png`.
- Today secondary routes:
  `design_qa/today-diary-current-2026-07-17.png` and
  `design_qa/signal-library-current-2026-07-17.png`.
- Weekly secondary routes:
  `design_qa/weekly-deep-analysis-2026-07-17.png` and
  `design_qa/weekly-next-week-tries-2026-07-17.png`.
- Life Experiment secondary routes, 390 × 844 pt at 2×:
  `design_qa/experiment-feedback-secondary-390x844-2026-07-17.png` and
  `design_qa/experiment-goal-detail-390x844-2026-07-17.png`.
- Journey secondary routes:
  `design_qa/journey-pro-secondary-current-2026-07-17.png` and
  `design_qa/journey-journal-secondary-current-2026-07-17.png`.

State: Simplified Chinese, light appearance, deterministic populated fixtures,
and representative review, plan, feedback, journal, and Pro states.

### Full-view and focused same-input comparisons

- Four-route full semantic comparison:
  `design_qa/comparison-four-page-hero-system-2026-07-17.png`.
- Today and Journey secondary comparison:
  `design_qa/comparison-today-journey-secondary-heroes-2026-07-17.png`.
- Weekly secondary comparison:
  `design_qa/comparison-weekly-secondary-heroes-2026-07-17.png`.
- Life Experiment secondary comparison:
  `design_qa/comparison-life-experiment-secondary-390x844-2026-07-17.png`.

Focused comparisons are necessary because title wrapping, compact raster
masking, metadata localization, and small-hero placement cannot be judged
reliably from the main-page overview alone.

### Required fidelity surfaces

- Fonts and typography: all routes use the lighter Today hierarchy, system
  font fallback, readable optical weights, and intentional Chinese wrapping.
  No mid-word English break or oversized heavy display copy remains.
- Spacing and layout rhythm: copy retains calm left-side reading space while
  artwork concentrates on the right; safe areas, glass cards, radii, section
  gaps, persistent navigation, and scroll content use the shared rhythm.
- Colors and visual tokens: all four illustrations use the app icon's palette
  and existing Aurora surfaces while maintaining distinct page semantics.
- Image quality and asset fidelity: the assets remain sharp at phone size.
  Horizontal and vertical alpha masks remove rectangular raster edges from
  compact secondary heroes without flattening the luminous details.
- Copy and content: workflow copy is preserved. Display localization prevents
  raw `growth_plan`, `food_sleep`, `neutral`, `active`, and `life experiment`
  values from leaking into Chinese UI; approved `Pro`, `AI`, `Signal Path`,
  and `Signal Card` remain unchanged.

### Comparison history and findings

1. The initial same-input comparison confirmed the four main semantic
   directions but found P2 secondary-page polish issues: a Today diary fixture
   without asset precache, visible rectangular raster edges, raw internal
   metadata, and a narrow Life Experiment trend-label overflow.
2. Fixes added deterministic asset precaching, two-direction alpha masks,
   localized display labels, deliberate Chinese title wrapping, and responsive
   trend-row space. These are presentation fixes only.
3. A final focused audit then found three additional P2 details: an internal
   `context_switching` timeline tag, the compact goal title splitting
   `离屏恢复`, and the Journey journal bottom navigation wrapping
   `生活小实验`. These were fixed with the existing taxonomy-localization
   helper, a compact responsive detail hero, and the shared one-line 11 pt
   navigation-label treatment.
4. Revised captures were generated at the same viewports and recombined. The
   current Life Experiment evidence shows `进行中 · 生活小实验`; the stale
   `active · life experiment` label is absent.
5. Final comparisons show no actionable P0, P1, or P2 fidelity issue. No P3
   work is required for this visual-system pass.

### Interactions and automated verification

- Existing coverage verifies tab routes, back navigation, filters, report
  opening, feedback controls, candidate surfaces, diary browsing, Journey Pro,
  and journal content. The test harness reported no remaining exceptions.
- Combined targeted Flutter regression: 92 / 92 passed serially across shared
  Aurora heroes, four route families, and five design-QA render suites.
- One parallel Widget-test timing fluctuation did not reproduce in isolation;
  its isolated rerun and the complete serial rerun passed.
- Targeted static analysis: 14 files, no issues found.
- No compile, archive, or TestFlight build was performed, as requested.

final result: passed

## Small-try and goal detail refactor — 2026-07-22

This pass separates the two Life Experiment detail experiences according to
their confirmed product roles. A small try is an immediate behavior that must
fit within ten minutes; a goal is a longer observation that can continue for
weeks and has no implicit seven-day end.

### Visual truth, viewport, and state

- Previous goal-detail implementation at 390 × 844 pt:
  `design_qa/experiment-goal-detail-390x844-2026-07-17.png`.
- Refactored small-try detail at the same viewport and populated active state:
  `design_qa/experiment-small-try-detail-390x844-2026-07-22.png`.
- Refactored goal detail at the same viewport and populated active state:
  `design_qa/experiment-goal-detail-390x844-2026-07-22.png`.

The comparison keeps Simplified Chinese, light appearance, the same Aurora
surface system, and representative active items. The implementation capture
uses a 390 × 844 logical viewport and a 2× PNG output (780 × 1688 px).

### Same-viewport comparisons

- Previous versus refactored goal detail:
  `design_qa/comparison-experiment-goal-detail-refactor-2026-07-22.png`.
- Refactored small try versus refactored goal:
  `design_qa/comparison-experiment-detail-types-2026-07-22.png`.

### Required surfaces and findings

- Information architecture: the generic tabs, aggregate statistics, and
  fixed seven-day presentation were removed from the active detail flows.
- Small try: the hero states “quick try / start anytime”; the page shows
  per-attempt structured effect and effort, read-only attempt history, one
  recording action, and a separate round review.
- Goal: the page separates the observation question, sustained action,
  minimum observation threshold, long-term progress, append-only daily facts,
  and stage/cycle review history.
- Typography and density: Chinese headings wrap by phrase, the hierarchy uses
  the established lighter Today standard, and no text or control overflow was
  found at supported widths or 1.3× text size.
- Color, imagery, and rhythm: both detail types reuse the Life Experiment
  branching artwork, Aurora glass cards, cream/lavender/mint palette, radii,
  safe-area spacing, and minimum 44 pt controls. Their structures differ
  without appearing to belong to different products.
- Interaction: back navigation, record actions, review sheets, completion
  confirmation, and the read-only historical projections remain functional.

The previous detail mixed lifecycle, overview, feedback, conditions, and notes
into one generic experiment template. The final comparison confirms that the
new pages communicate “try once and judge immediately” versus “observe over
time and review by stage” without relying on explanatory tabs. No remaining
P0, P1, or P2 visual issue was found.

### Automated verification

- 135 related repository, feedback, and widget tests passed serially.
- 2 deterministic 390 × 844 design-render tests passed.
- Targeted static analysis of 15 implementation and test files passed with no
  issues.
- No compile, archive, or TestFlight build was performed in this pass.

final result: passed

## Bottom navigation unification — 2026-07-29

This pass makes Today the single five-tab navigation contract and removes the
separate diary implementation that had drifted from it.

### Source and implementation evidence

- Desired Today source:
  `/Users/yangyang/Pictures/照片图库.photoslibrary/resources/renders/3/38ECDD2B-7EEE-4A07-B906-13C1E3D1C5E9_1_201_a.jpeg`
  (1290 × 2796 px).
- Reported diary source:
  `/Users/yangyang/Pictures/照片图库.photoslibrary/resources/renders/4/49155E8A-0B22-4AA1-A717-750ADAF0B508_1_201_a.jpeg`
  (1290 × 2796 px).
- Fixed diary implementation:
  `design_qa/today-diary-current-2026-07-17.png`
  (390 × 844 logical viewport; 780 × 1688 px capture).
- Desired Today versus fixed diary comparison:
  `design_qa/comparison-today-nav-vs-diary-nav-2026-07-29.png`.
- Reported diary versus fixed diary comparison:
  `design_qa/comparison-bottom-navigation-source-vs-implementation-2026-07-29.png`.

### Findings and corrections

1. The production audit found two complete five-tab implementations. The
   diary was the only independently maintained duplicate; no third variant
   remains.
2. Today and the diary now use one shared component with the same icons,
   labels, gradient, 26 pt radius, dimensions, spacing, selection treatment,
   route behavior, safe-area behavior, and accessibility semantics.
3. The combined same-height comparison confirms that the diary now uses the
   Today chat-bubble selection instead of the obsolete sun/bar-chart/compass
   set.

### Automated verification

- 11 / 11 targeted diary and shell navigation tests passed.
- 12 / 12 release UI guardrails passed across four device sizes, four
  languages, 1.3× text, minimum touch areas, and VoiceOver semantics.
- Static analysis passed with no issues.
- The populated diary design render passed.
- No compile, archive, or TestFlight build was performed, as requested.

final result: passed

## Reported spacing corrections — 2026-08-01

This pass addresses the eleven circled empty regions reported in the supplied
390 pt iPhone screenshots. It keeps the existing Aurora artwork, cards,
typography, floating navigation, and page information architecture intact.

### Same-state visual evidence

- Weekly deep-analysis hero, before and after:
  `design_qa/spacing-2026-08-01/comparison-weekly-hero.png`.
- Action-preference hero, before and after:
  `design_qa/spacing-2026-08-01/comparison-action-hero.png`.
- Journey Pro hero, before and after:
  `design_qa/spacing-2026-08-01/comparison-journey-hero.png`.
- Monthly calendar gap, before and after:
  `design_qa/spacing-2026-08-01/comparison-calendar-gap.png`.
- Journey content-to-navigation gap, before and after:
  `design_qa/spacing-2026-08-01/comparison-bottom-gap.png`.

### Findings and corrections

1. Several secondary-page heroes used fixed minimum heights plus independently
   positioned back controls. The back control and title now share one row, and
   the weekly, action-preference, and Journey Pro heroes size to their content.
2. Main pages used `Scaffold.extendBody` while their shared scroll padding read
   the Scaffold-injected bottom padding and then added another navigation
   clearance. The shared calculation now uses physical safe-area insets, so the
   floating navigation is reserved exactly once on Today, Weekly, Life
   Experiment, Journey, and Me.
3. The monthly calendar's nested `GridView` inherited the parent media padding,
   inserting a navigation-height gap between the final week and its legend. It
   now has explicit zero padding and remains non-primary.
4. The Me hero no longer holds a fixed-height lower area. The subscription
   management action now uses the full available row as a 44 pt accessible
   control instead of leaving an unexplained empty half-row.
5. Weekly deep analysis and Journey Pro now keep the shared five-tab bottom
   navigation around loading, empty, error, and ready states.
6. Combined reference-and-implementation comparisons were inspected at the
   supplied mobile state. No remaining P0, P1, or P2 spacing mismatch was found.

### Automated verification

- 70 / 70 targeted widget, spacing, and shell-navigation tests passed.
- 11 / 11 deterministic design-render tests passed.
- Static analysis passed for 16 changed implementation, test, and render files
  with no issues.
- No compile, archive, or TestFlight build was performed in this pass.

final result: passed

## Spot try terminology and Journey Pro report boundaries — 2026-08-01

### Same-state visual evidence

- Experiment track terminology, before and after:
  `design_qa/spacing-2026-08-01/comparison-spot-try-label.png`.
- Journey Pro month boundary and canonical theme legend, before and after:
  `design_qa/spacing-2026-08-01/comparison-journey-complete-month-domains.png`.

### Findings and corrections

1. The short-form experiment position is now consistently named `Spot try` /
   `Spot tries`, `简单尝试`, `簡單嘗試`, and `スポットトライ` throughout
   onboarding, Experiment, Today, Weekly, candidate selection, and offline
   candidate generation. The long-form track remains `Goal / 中长期`.
2. Real duration facts remain quantitative: feedback buckets, 1–10 minute
   creation constraints, concrete 1/2/3–5/10 minute suggestions, and observed
   “under ten minutes was easier” conclusions were not renamed.
3. Journey Pro computes its final date as the last day of the previous local
   calendar month. Current/future route selections cannot reveal the unfinished
   month, and the first in-progress month produces an honest empty report.
4. Both focus and theme projections pass through the same nine canonical Focus
   Domains. Unknown theme evidence falls back to its canonical focus domain;
   `other` and “其他线索” are not reachable in Journey Pro charts.

### Automated verification

- 100 / 100 terminology and affected-page tests passed, including a source
  guardrail that rejects legacy visible type labels.
- 7 / 7 Journey Pro repository boundary/classification tests passed, including
  current/future selection and an explicit nine-domain cardinality assertion.
- 6 / 6 final-state design-render tests passed.
- Static analysis passed for 18 implementation and test files with no issues.

final result: passed
