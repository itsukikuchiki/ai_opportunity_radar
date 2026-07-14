# Feedback Event

Last updated: 2026-07-12

FeedbackEvent is the active read model for feedback across modules.

## Sources

| Source | FeedbackEvent source type |
| --- | --- |
| Micro action feedback | `micro_action_feedback` |
| Life experiment feedback | `life_experiment_feedback` |

The current implementation uses `FeedbackEventModel` and `LocalFeedbackEventRepository` as a repository-level unified view. A SQL view/table can replace the internals later without changing callers.

Candidates cannot receive progress feedback. Feedback starts only after an
explicit adoption has created a formal `MicroAction` or `LifeExperiment`.
Likewise, choosing Inaccurate or Do not add for an AI/Library proposal creates
no match-feedback row and no `FeedbackEvent`; the decision is zero-write.

## Progress Projection

The implemented baseline `X/7` projection is derived from source feedback rather
than stored as a decorative UI value:

- group events by item and the user's local calendar date;
- use the last valid event for the item on that date;
- `occurred` / `happened` contributes one completed day;
- `not_occurred` / `not_suitable_today` contributes zero;
- preserve all events as history even when the latest event changes progress;
- clamp the projection to the approved fixed seven-day window;
- never use MicroAction counts as LifeExperiment progress or vice versa.

The repositories and active UI read the same distinct-local-date progress
contract. Real-device QA must still verify locale, midnight, same-day edit, and
seven-cell accessibility behavior.

## Consumers

| Consumer | Usage |
| --- | --- |
| Weekly | Adds feedback to AI/source hash and exposes `_feedback_event_summary`. |
| Journey | Builds traces and trend input from unified feedback. |
| Life Experiment | Shares feedback with rollups and evidence. |
| Today | Shows adopted item progress and allows a new daily event. |

## Compatibility Boundary

`schedule_feedback` and `goal_feedback` may still be decoded by the lower
repository for old-data migration and deletion, but they are excluded from the
active Today, Weekly, Journey, and timeline read models. They must not unlock or
shape Signal/MicroAction/LifeExperiment suggestions.
