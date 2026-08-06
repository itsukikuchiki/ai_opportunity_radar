# Feedback Event

Last updated: 2026-07-28

FeedbackEvent is the active read model for feedback across modules.

## Sources

| Source | FeedbackEvent source type |
| --- | --- |
| Life Experiment / quick try (`小实验`) feedback | `micro_action_feedback` |
| Life Experiment / goal (`目标`) feedback | `life_experiment_feedback` |

The current implementation uses `FeedbackEventModel` and `LocalFeedbackEventRepository` as a repository-level unified view. A SQL view/table can replace the internals later without changing callers.

The unified read model exposes `life_experiment_kind = quick_try | goal`.
Legacy rows derive this discriminator from their source table when it is absent;
the discriminator is required for section placement and copy, but never changes
the source event's identity.

Candidates cannot receive progress feedback. Feedback starts only after an
explicit adoption has created a formal quick try (`MicroAction` compatibility
storage) or goal (`LifeExperiment` compatibility storage). Both appear under
the Life Experiment product surface, but keep independent event identities and
rollups.
Likewise, choosing Inaccurate or Do not add for an AI/Library proposal creates
no match-feedback row and no `FeedbackEvent`; the decision is zero-write.

Every saved feedback/review/lifecycle row is immutable and append-only. The
active UI may write only for the current user-local date. A second choice on
that same date creates another event rather than updating the first, while a
past date or completed period exposes no edit or backfill operation. Planning
content for the current or next user-local week may be revised through a
separate prospective plan-version path; that is not a FeedbackEvent edit.

Lifecycle completion is reconciled at the local-week boundary, not by a manual
detail action. Weekly's next-week selection creates an idempotent linked child
for every adopted quick try or goal the user chooses to continue. The child
activates on the next local Monday; without a child, the current projection
becomes completed at its own Sunday boundary. Reconciliation creates no
FeedbackEvent, outcome review, effort review, conclusion, or Signal. Historical
lifecycle rows remain immutable and read-only; they never become a current
write path.

## Completion And Outcome Projections

Completion and effectiveness are separate append-only facts. A completion
event never becomes a positive/negative outcome unless the user explicitly
submits an outcome review.

### Quick try (short term)

- each actual attempt takes no more than ten minutes and is its own event;
- multiple attempts on one local date remain separate rather than collapsing
  to one daily cell;
- after a real attempt, collect immediate effect
  `helpful | somewhat | no_effect`, effort `easy | okay | effortful`, and an
  optional sentence through one shared Today / Weekly write path;
- no review is `awaiting review`; one positive review is `early help`;
- at least two positive (`helpful` or `somewhat`) attempts, with acceptable
  overall burden and `effortful` not the majority, are required before the UI
  may say `worth keeping`;
- positive but effortful/context-dependent becomes `adjust`; at least two
  reviewed attempts with no positive result becomes `no help observed yet`;
- the usefulness projection never decides whether the object continues.
  Continuation is selected only on Weekly's next-week page; no manual “end
  observation” or formal-complete action exists.

### Goal (medium/long term)

- the goal defines its cadence, observation period, and minimum valid
  observation days; the default minimum is three, but a goal may require more;
- the observation period may exceed seven days;
- cadence completion uses `completed | not_completed | empty` by user-local
  date; the last valid event for the same goal/date is the effective cell while
  all older correction events remain immutable;
- when the current local Monday-Sunday range contains at least one valid goal
  feedback event, Weekly may append a `weekly` review for that week; below the
  goal's minimum observation threshold it must stay cautious and use
  `unclear` rather than claim a directional result;
- Life Experiment may append a `whole_round` review when the observation
  threshold is met or the user explicitly summarizes the complete goal; an
  early or below-threshold round likewise permits only `unclear`;
- both typed reviews collect outcome `improved | somewhat | unchanged | worse |
  unclear`, effort `easy | acceptable | too_effortful`, and an optional
  sentence; neither review completes the goal;
- below threshold or `unclear` is `not enough to tell`; improvement is
  `appears helpful this round`; improvement plus excessive effort is `helpful,
  needs lightening`; unchanged is `no effect observed yet`; worse is `current
  approach may not fit`; only two consecutive same-direction positive rounds
  may be described as `more stable across rounds`.

Historical MicroAction aliases (`occurred`, `happened`, `yes`, `done`,
`not_occurred`, `not_happened`, `no`, `not_suitable_today`, `skipped`) and
historical LifeExperiment aliases (`tried`, `helpful`, `adjusted`, `not_today`)
remain read-only compatibility inputs. They cannot be accepted as new writes or
converted into the new structured effect/effort or period-outcome review.

The repositories, active UI, Weekly summary, Life Experiment rollup, and the
redesigned Journey projection reuse these same typed events. Real-device
QA must verify locale, midnight, multiple same-day quick-experiment attempts,
same-day goal corrections, flexible goal periods, historical read-only
behavior, and accessibility. Journey must preserve attempt, round review, goal
daily fact, goal weekly review, and goal whole-round review as different source
kinds; readiness still counts eligible SignalCards only. This is now an
**Implemented baseline**: the unified feedback repository exposes and
invalidates the events, and `MemoryRepository` consumes them as distinct
selected-month statistics/traces and all-history-through-period source-hash
inputs. Feedback and reviews never increment Signal readiness. TestFlight QA
remains open for the boundaries above.

## Consumers

| Consumer | Usage |
| --- | --- |
| Weekly | Adds feedback to AI/source hash and exposes `_feedback_event_summary`. |
| Journey | **Implemented baseline; device QA pending.** Builds a selected-month read-only trajectory from quick-experiment attempts and round reviews plus goal daily, weekly, and whole-round events. Same-day quick-experiment attempts remain separate; goal daily corrections use the last valid event only for that day's effective cell while history remains append-only. Reviews enter factual tracks and the through-period synthesis/hash context but never increment Journey readiness. |
| Life Experiment | Shows quick-experiment attempt dots and goal longitudinal tracks on the home page, writes whole-round goal reviews, and retains individual object details and immutable history. Base access includes source Signal, current and historical plan versions, fact history, and latest review; only full cross-round review history is Pro. There is no separate aggregate detail/archive-overview route. |
| Today | Shows at most three adopted small experiments and three adopted goals at the bottom and writes through the same per-attempt/cadence feedback path. |
| Diary Timeline | Projects each type separately for the selected local date and computes progress only through that date. |

## Compatibility Boundary

`schedule_feedback` and `goal_feedback` may still be decoded by the lower
repository for old-data migration and deletion, but they are excluded from the
active Today, Weekly, Journey, Life Experiment, and diary read models. They must
not unlock or shape Signal/quick-try/goal suggestions.
