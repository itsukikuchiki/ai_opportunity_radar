# Design QA — primary app pages

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
- Small try: the hero states “within 10 minutes / can try now”; the page shows
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
