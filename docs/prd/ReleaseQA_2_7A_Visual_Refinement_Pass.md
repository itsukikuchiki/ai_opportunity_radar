# ReleaseQA-2.7A Visual Refinement Pass

## Status

Engineering implemented / ready for visual review.

This pass refines the ReleaseQA-2.7 visual redesign evidence harness. It does not change the Phase 3 data chain, privacy boundaries, purchase logic, Pro logic, quota logic, EventKit integration, or HealthKit integration.

## Refinement Scope

- Removed forced custom font family to avoid Latin title rendering artifacts.
- Added product review screenshot mode with no evidence filename, no page counter, and no QA footer.
- Added a branded splash / launch-style scene using signal dots plus a soft path.
- Reduced schema-like wording in user-facing UI copy.
- Replaced technical tags with user-language labels where visible.
- Strengthened the Weekly energy stacked bar into a clearer horizontal proportional bar with a single legend row.
- Expanded Journey Life Map into a fuller path / constellation visual.
- Added a 10-minute buffer mini time strip to the Plan Block visual.
- Kept visual style soft, non-diagnostic, and non-score-based.

## Screenshot Modes

Two screenshot sets are expected under:

```text
/private/tmp/signalpath_releaseqa_phase3_visual_refinement/
```

### Evidence screenshots

```text
/private/tmp/signalpath_releaseqa_phase3_visual_refinement/evidence/
```

Evidence screenshots keep the top filename, page count, and QA footer for traceability.

### Product review screenshots

```text
/private/tmp/signalpath_releaseqa_phase3_visual_refinement/product_review/
```

Product review screenshots hide the evidence top bar, page count, and QA footer so the pages feel closer to real app review visuals.

## Screenshot List

The screenshot set includes:

```text
00_splash_launch.png
01_today_signal_feed_full.png
02_signal_composer_input.png
03_voice_transcript_edit.png
04_ai_predicted_confirm_mode.png
05_library_saved_timeline_card.png
06_signalcard_compact_state.png
07_plan_block_local_only.png
08_weekly_life_dashboard.png
09_weekly_energy_stacked_bar.png
10_life_experiment_feedback.png
11_energy_budget_block.png
12_journey_life_map.png
13_journey_heatmap_review_adjust.png
14_signal_library_cards.png
15_library_share_preview.png
```

## Boundary Checks

- No Phase 3 persistence behavior changed.
- No save-first behavior changed.
- No purchase, Pro, restore, or quota behavior changed.
- No real EventKit permission or Calendar write was added.
- No real HealthKit permission or health dashboard was added.
- Voice remains transcript-only in this evidence harness.
- Calendar / Health wording remains abstract and advisory only.
- Signal Library share preview contains only official abstract pattern content.

## Validation Commands

```bash
cd frontend_flutter
flutter analyze
flutter test
git diff --check
```
