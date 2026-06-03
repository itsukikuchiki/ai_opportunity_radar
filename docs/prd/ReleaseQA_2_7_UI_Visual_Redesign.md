# ReleaseQA-2.7 UI Visual Redesign

## Status

Engineering implemented / ready for visual review.

This pass keeps the Phase 3 data chain unchanged. It only updates the visual evidence harness used for release review screenshots.

## Goals

- Move the screenshots away from report-like explanation pages.
- Make Today feel like a private signal feed.
- Make Weekly and Energy Budget feel like light dashboards, not long analysis reports.
- Make Journey feel like a long-term life map.
- Make Signal Library feel like an official curated pattern card library, not a community feed.
- Keep all privacy, save-first, AI predicted, voice, library_saved, EventKit, and HealthKit boundaries unchanged.

## Visual Principles

- Each page uses one primary visual element before detail cards.
- Text is reduced to one short page sentence plus compact card copy.
- Raw user-facing examples stay synthetic and privacy-safe.
- Visual elements carry meaning: dots, strips, waveform, heatmap, map trail, ring, share card, and pattern cards.
- Charts show distribution and clues, not scores, diagnosis, performance, or health evaluation.

## Page-by-Page Implementation Notes

1. `01_today_signal_feed_full`  
   Reframed as Today private signal feed with signal dot cluster, summary strip, and multiple SignalCards.

2. `02_signal_composer_input`  
   Reframed as a real Signal Composer with input affordance and quick actions.

3. `03_voice_transcript_edit`  
   Reframed as voice-to-editable-transcript with waveform visual. Voice remains transcript-only.

4. `04_ai_predicted_confirm_mode`  
   Reframed as AI suggestion spotlight with confirmation chips and low-pressure copy.

5. `05_library_saved_timeline_card`  
   Reframed as a two-layer Library saved observation: official pattern plus private context.

6. `06_signalcard_compact_state`  
   Defines the compact SignalCard shape: source, time, raw note, short AI response, tags, and confirmation.

7. `07_plan_block_local_only`  
   Reframed as a sticky-note style optional plan block, not task management.

8. `08_weekly_life_dashboard`  
   Reframed as Weekly life dashboard with weather strip, main insight, and one small experiment.

9. `09_weekly_energy_stacked_bar`  
   Reframed as a polished distribution bar with legend and abstract external hints.

10. `10_life_experiment_feedback`  
    Reframed as an experiment card plus feedback card. Skipped or adjusted states remain normal evidence.

11. `11_energy_budget_block`  
    Reframed as Energy Budget Lite with ring visual, costly source, and recovery clue.

12. `12_journey_life_map`  
    Reframed as a long-term life map with trail and week nodes.

13. `13_journey_heatmap_review_adjust`  
    Reframed with heatmap as the primary visual and a Review & Adjust card.

14. `14_signal_library_cards`  
    Reframed as official curated pattern cards.

15. `15_library_share_preview`  
    Reframed as an actual share-card preview containing only official abstract pattern content.

## Illustration Rules

- Use abstract dots, waves, trails, bubbles, soft strips, and symbolic shapes.
- Do not use realistic people, identifiable scenes, or user stories.
- Keep visuals soft and light, with muted semantic colors.

## Chart Rules

- Allowed: stacked bar, heatmap, ring, dot cluster, waveform, path map.
- Not allowed: score dashboard, diagnostic chart, performance chart, health judgement, or raw timeline evidence.

## Screenshot Output

Simulator screenshots should be saved to:

```text
/private/tmp/signalpath_releaseqa_phase3_visual_redesign/
```

Expected files:

```text
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

## Known Trade-offs

- This pass updates the release QA evidence harness, not the production page architecture.
- It does not change Phase 3 persistence, parser, quota, purchase, or backend behavior.
- It does not connect real EventKit or HealthKit permissions.
- Voice remains transcript-only in this evidence pass.
- External Calendar / Health hints remain sanitized abstract hints only.

## Validation Commands

```bash
cd frontend_flutter
flutter analyze
flutter test
git diff --check
```
