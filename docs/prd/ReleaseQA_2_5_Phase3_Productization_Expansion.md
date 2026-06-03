# ReleaseQA-2.5 Phase 3 Productization Expansion

Status: Engineering implemented

## Scope

This pass keeps the Phase 3 data chain intact and makes the current product feel less like a diary form and more like a private signal system. It does not add real EventKit or HealthKit access, does not add a schedule or health dashboard, and does not change purchase / Pro / quota QA.

## Implemented

- Today keeps the app tab title as `Today`, but the main header now presents the experience as `Signal Feed`.
- The capture box is now `Signal Composer`, with lower-pressure copy and a shorter save flow.
- SignalCards now prioritize raw text, one saved AI response, and at most three parsed tags.
- Voice Input MVP is transcript-only: users can edit text before saving; no audio is saved or uploaded.
- AI Predicted Confirm Mode is user-triggered only. It creates `source_type = ai_predicted`, private / unconfirmed SignalCards and does not enter Summary / Weekly / Journey / Energy Budget until confirmed.
- Weekly adds a local-only `Plan Block` action for one small experiment. It creates no calendar event, notification, or task.
- Weekly Energy Budget now includes a display-only stacked energy distribution bar. It is not a score or diagnosis.
- Journey adds a lightweight life-map heatmap after the Review & Adjust section.
- Signal Library cards are shorter and can copy/share official abstract pattern text only. No user raw text or user story is included.

## Privacy / Evidence Boundaries

- `raw_text` remains private and is never used for Signal Library sharing.
- `library_saved` observations remain private and unconfirmed by default.
- `ai_predicted` observations remain private and unconfirmed by default.
- Calendar / HealthKit real permissions are still not connected in this pass.
- External hints remain abstract only and cannot override user-confirmed SignalCards.
- `included_in_*` still means “used by that layer”, not confirmed or high-confidence evidence.

## Validation

Required commands for this pass:

- `flutter analyze`
- `flutter test`
- `git diff --check`

Backend pytest is not required because this pass only touches Flutter client code and docs.
