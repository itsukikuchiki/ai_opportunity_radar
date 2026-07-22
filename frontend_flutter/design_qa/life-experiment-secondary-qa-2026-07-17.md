# Life Experiment secondary-page visual QA — 2026-07-17

## Comparison target

- Source visual truth: `design_qa/experiment-current-2026-07-17.png`
  (approved Life Experiment main-page branching artwork, pearl-glass palette,
  typography weight, card treatment, and experiment semantics).
- Implementation screenshots:
  - `design_qa/experiment-feedback-secondary-390x844-2026-07-17.png`
  - `design_qa/experiment-goal-detail-390x844-2026-07-17.png`
- Same-input full-view comparison:
  `design_qa/comparison-life-experiment-secondary-390x844-2026-07-17.png`
- Viewport: 390 × 844 pt, Simplified Chinese, 1.0× text scale.
- States: an active seven-day goal feedback form and the corresponding goal
  detail overview.

## Required fidelity surfaces

- Fonts and typography: both secondary pages retain the same system CJK
  hierarchy and lighter optical weights as the approved main page. Copy wraps
  at phrase boundaries without clipping primary actions.
- Spacing and layout rhythm: both pages use the 22 pt main-page inset, 24–28 pt
  glass-card radii, safe top spacing, and scrollable content at 390 × 844. The
  goal-detail trend labels were changed to equal-width flexible cells, closing
  a 12 px overflow at this viewport.
- Colors and visual tokens: warm cream, pale lavender, ice blue, navy, mint,
  orange, and violet remain consistent across the three comparison panes.
- Image quality and asset fidelity: the main and both secondary pages render
  the same real raster `AuroraExperimentHeroPattern` asset. A vertical alpha
  mask removes the former hard rectangular top/bottom seam while preserving
  the luminous branching paths and Signal nodes.
- Copy and content: all existing goal, feedback, lifecycle, and progress copy
  remains unchanged; no workflow, state, or data chain was modified.

## Comparison history

1. Initial feedback and detail renders used the correct artwork, but the
   secondary-page 0.44 opacity reduced the experiment motif to a faint crop.
   The asset also ended with a visible rectangular lower edge.
2. The secondary opacity was raised to 0.68 and the shared experiment artwork
   gained a top/bottom fade in addition to its left-edge fade.
3. The first 390 × 844 goal-detail capture exposed a 12 px trend-label
   overflow. Labels now use equal-width flexible cells with single-line fade.
4. The post-fix same-input comparison shows the same branching art direction,
   palette, glass surfaces, and hierarchy across the main, feedback, and detail
   views, with no remaining P0, P1, or P2 issue.

## Automated verification

- Screenshot QA: 2/2 passed.
- Focused Aurora, experiment archive/detail, and feedback tests: 16/16 passed.
- Targeted `flutter analyze`: no issues found.

Focused crops were not needed: the 390 × 844 combined input keeps the hero,
title hierarchy, cards, controls, and detail chart labels readable at original
device scale.

final result: passed
