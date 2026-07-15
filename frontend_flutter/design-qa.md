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
5. Rebuilt Journey with the road hero, separate Free 7/3 and Pro 14/7/2 readiness, factual views, evidence entry points, and an explicit forming state.
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
