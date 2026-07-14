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
