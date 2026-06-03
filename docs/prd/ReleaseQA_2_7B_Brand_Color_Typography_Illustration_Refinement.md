# ReleaseQA-2.7B Brand / Color / Typography / Illustration Refinement

Status: Engineering implemented / ready for visual review

## Scope

ReleaseQA-2.7B is a visual refinement pass only.

This pass does not change:

- Phase 3 data chains
- SignalCard schema or inclusion rules
- privacy boundaries
- Purchase / Pro / quota behavior
- real EventKit / HealthKit integration

## Changes

### Brand System

- Added a reusable Signal Path logo visual based on signal dots and a soft path.
- Updated the splash / launch evidence scene into a product-like launch screen.
- Kept the tagline: `看见信号，轻轻调整`.
- Removed explanatory QA copy from the product splash scene.

### Color Tokens

- Softened the core palette and added named visual tokens:
  - `signalBlue`
  - `recoverySage`
  - `switchTeal`
  - `drainCoral`
  - `bufferButter`
  - `librarySand`
  - `privateMist`

These tokens are used only in the Release QA visual harness.

### Typography

- Reduced heavy title weights in the screenshot harness.
- Kept titles clear but lighter, with less “dashboard pressure”.
- Product screenshots use Simplified Chinese as the primary language.

### Illustration Components

Added reusable illustration components for product screenshots:

- `SignalPathLogoVisual`
- `BufferTimelineVisual`
- `ExperimentBeforeAfterVisual`
- `LibraryFlowVisual`
- `SwitchingBurdenVisual`
- `PatternIllustration`

Existing visuals were refined:

- Splash uses signal dots + path.
- Weekly adds switching burden structure.
- Plan Block uses a clear 10-minute buffer strip.
- Life Experiment uses before / buffer / lighter path.
- Journey Life Map uses a fuller constellation / path map with legend.
- Signal Library cards use abstract pattern illustrations.
- Share Preview remains official-pattern only.

### Product-Like App Frames

Added five product-review scenes with real app frame structure and bottom navigation:

- Today
- Weekly
- Journey
- Library
- Me

These scenes are intended to show the interface as an app, not as a QA document.

## Screenshot Output

Product-review screenshots should be generated to:

```text
/private/tmp/signalpath_releaseqa_phase3_visual_refinement_product/
```

Product-review mode hides:

- file-name labels
- page counters
- QA footer copy

## Privacy Boundary

The screenshot harness continues to use synthetic demo data only.

No screenshot includes:

- real user raw text
- raw Calendar data
- raw HealthKit data
- audio files
- user-identifiable story content

Signal Library share content remains official abstract pattern only.

## Validation

Required checks:

```bash
cd frontend_flutter
flutter analyze
flutter test
cd ..
git diff --check
```

Current result:

- `flutter analyze`: passed
- `flutter test`: passed, 109 tests
- `git diff --check`: clean

## Remaining Release QA Boundary

This pass improves screenshot/product review evidence only.

It does not replace:

- TestFlight purchase QA
- real subscription restore QA
- final archive/upload verification
- real EventKit / HealthKit platform integration
