# Phase 3 Final Page Data Structure Acceptance

Date: 2026-06-16

This document maps every current main app page section to its data collection,
storage, report generation, privacy boundary, and remaining release validation.

## Global Evidence Rules

- `SignalCard` is the main evidence source for Today, Weekly, Journey, Energy
  Budget, and Library-saved observations.
- User raw input is saved before AI parsing or reply generation.
- AI failure, quota exceeded, or backend unreachable must not prevent local
  record saving.
- `included_in_summary`, `included_in_weekly`, and `included_in_journey` mean
  "used by this view/snapshot"; they do not mean confirmed or high confidence.
- Calendar and HealthKit are optional advanced hints. They are auxiliary context
  only and cannot override user-confirmed SignalCards or user feedback.
- Signal Library is official curated content only. It must not use user raw text,
  private context, raw Calendar data, or raw HealthKit samples.
- Phase 3+ adds `ScheduleSignal`, `Goal`, `GoalPlan`, `GoalTaskInstance`,
  `GoalFeedback`, `LifeExperimentStrategy`, and `LifeExperimentFeedback`.
  These are local-first evidence layers. They help Weekly/Journey understand
  arrangement load and goal fit, but they never replace user raw notes.

## Today

| Page section | Data collected / shown | Storage / model | Generation logic | Acceptance status |
| --- | --- | --- | --- | --- |
| Signal input | Text input, voice transcript draft, one-tap status, AI predicted prompt | `SignalCard`, local draft queue, `source_type` | Save-first capture path; AI parser/reply can fail without losing raw input | Implemented |
| Today overview | Energy, friction, recovery indicators | Today's eligible `SignalCard` list | Local aggregation from `energy_load`, `friction`, `positive_signal`, scene tags | Implemented |
| Today small observation | One short AI/local observation | `DailySnapshot` / Today summary state | SignalCard-based summary; local fallback if AI unavailable | Implemented |
| AI predicted signal | Suggested signal candidate | `SignalCard` only after save/confirmation path | Generated in current app language; unconfirmed prediction does not count as raw eligible signal | Implemented |
| Schedule signal | Manual arrangement title, optional date/time, scene, expected load | `schedule_signals` / `ScheduleSignalModel` | Title-only becomes `unscheduled`; date-only is pending; time-only defaults to today; exact date+time can later support reminders | Implemented |
| Schedule feedback | Feeling after an arrangement | `schedule_signals.feedback_status`, linked `SignalCard` via `linked_schedule_signal_id` | Feedback can create/associate a SignalCard; high drain/recovery/friction hints are inferred locally | Implemented |
| Goal practice | User goal and today's small goal task | `goals`, `goal_plans`, `goal_task_instances`, `goal_feedback` | Local rule-based plan creates minimum/standard/full tasks; feedback is optional and non-punitive | Implemented |
| Diary timeline | Same-day SignalCards with raw text, AI reply, tags, local status | `SignalCard`, local date/timezone | Grouped by user's local date; old records are preserved as legacy context | Implemented |
| Current weekly experiment | Experiment status and feedback | `LifeExperimentModel`, local experiment repository | Feedback is saved as Review & Adjust evidence, not a habit score | Implemented |
| Sync notice / retry | Pending local drafts and failed sync | local draft queue + retry result | Retry does not delete local data if backend remains unreachable | Implemented |

## Weekly

| Page section | Data collected / shown | Storage / model | Generation logic | Acceptance status |
| --- | --- | --- | --- | --- |
| Weekly Lite / Ready | Week state, date range, one short read | `WeeklyInsightModel`, weekly snapshots | Day 1+ local-day Lite; full Weekly requires 7 active app days and enough eligible signals | Implemented |
| Weekly weather | Energy/friction/recovery | `WeeklyChartPointModel`, SignalCard aggregation | Aggregates eligible SignalCards by local date/timezone | Implemented |
| One pattern | One primary weekly pattern | `WeeklyTopicFocusModel`, `WeeklyV3CStructureModel` | Low-pressure one-pattern extraction; fallback does not pretend deep analysis | Implemented |
| Drain chain | Weekly consumption chain | `WeeklyV3CStructureModel` | Derived from repeated scenes/frictions/energy load | Implemented |
| Energy Budget | Energy distribution and sources | `EnergyBudgetModel` | SignalCard-first; Life Experiment and optional external hints can add context | Implemented |
| Schedule / Goal signals | Known schedule count, pending schedules, feedback count, active goals | `_schedule_goal_summary` in `WeeklyInsightModel.opportunitySnapshot` | Local aggregation from `schedule_signals`, `goals`, `goal_task_instances`, and feedback; pending schedules are evidence, not failures | Implemented |
| One Weekly Focus | One direction only | `WeeklyTopicFocusModel` | WIP-limited focus derived from weekly pattern | Implemented |
| Life Experiment strategy | Strategy / design / development foundation | `life_experiment_strategies`, extended `life_experiments`, `life_experiment_feedback` | Strategy captures target pattern/evidence; design captures trigger/frequency/difficulty; development feedback captures happened/effect/next adjustment | Implemented foundation |
| Life Experiment | Suggested/saved/skipped/tried/not_helpful/adjusted | `LifeExperimentModel` | Optional small experiment; feedback preserved for Review & Adjust | Implemented |
| Inclusion explanation | Used vs timeline-only counts | `WeeklyInclusionSummaryModel` | Inaccurate, sync failed, local draft, excluded, sensitive are not used | Implemented |

## Journey / Review

| Page section | Data collected / shown | Storage / model | Generation logic | Acceptance status |
| --- | --- | --- | --- | --- |
| Long-term insight | One long-term reflection | `MemorySummaryModel` | SignalCard + experiment history; low-pressure Review & Adjust | Implemented |
| Long-term modes | Repeated, stable, shifting modes | `JourneySignalItemModel` | Aggregated from eligible SignalCards and evidence levels | Implemented |
| Life structure path | Long-term consumption/recovery chain | `MemorySummaryModel`, chain fields | Uses scenes, frictions, energy load, positive signals, experiment feedback | Implemented |
| Monthly life map | 2x3 monthly structure / heatmap | `MonthlyReviewModel`, `monthly_snapshots` | Monthly is no longer a standalone page; Journey attaches monthly review from the same generation logic | Implemented |
| Experiment trajectory | Effective, difficult, unstable experiment evidence | `LifeExperimentModel` history | skipped/not_helpful/adjusted are retained as learning evidence | Implemented |
| Schedule / Goal trajectory | Long-term arrangement and goal fit evidence | `schedule_signals`, `goals`, `goal_feedback`, `MemorySummaryModel.experiments` | Journey attaches schedule/goal evidence as Review & Adjust context; it is weak/repeated evidence depending on feedback volume | Implemented |
| Bottom insight | One gentle next adjustment | `MemorySummaryModel` | Review & Adjust output, not scoring or diagnosis | Implemented |

## Signal Library

| Page section | Data collected / shown | Storage / model | Generation logic | Acceptance status |
| --- | --- | --- | --- | --- |
| Category chips | Curated official pattern categories | `SignalLibraryPatternModel` | Official curated list only | Implemented |
| Resonance card | General abstract reassurance | Static/local curated content | No user raw text or story | Implemented |
| Pattern cards | Title, possible structure, observation, small experiment | `SignalLibraryPatternModel` | Official abstract pattern metadata | Implemented |
| I also have this | Private local action | `SignalLibraryActionModel` / local action table | Does not create public interaction data | Implemented |
| Save | Private personal observation | private `SignalCard` with `source_type = library_saved` | raw text is empty unless user later adds their own context | Implemented |
| Share | Official abstract share content | curated pattern only | Must not include user raw text, user context, or private action | Implemented |

## Me

| Page section | Data collected / shown | Storage / model | Generation logic | Acceptance status |
| --- | --- | --- | --- | --- |
| Welcome card | Local profile / app state | local app state | Management entry only; no analysis | Implemented |
| My usage style | Focus area, language, AI response style | local preferences | User preference controls language and response style | Implemented |
| Apple sign-in backup | Apple account identifier and private backup snapshot | `CloudBackupRepository`, backend account backup | Local-first remains; cloud backup is snapshot restore, not realtime multi-device sync | Implemented |
| My data | Diary/review, advanced signals, privacy, delete account | local DB + backend backup delete | Delete account removes local data, cloud backup, Apple-linked app account; restart behaves as new user | Implemented |
| Advanced signal settings | Calendar / HealthKit optional permission actions | EventKit / HealthKit bridge, `ExternalEnergyHintStore` | Saves only abstract hints; raw event/health details do not flow downstream | Implemented; needs TestFlight/real-device permission QA |
| Pro | Entitlement and quota display | App Store purchase state, usage counters | Free/Pro quota and restore purchase remain App Store controlled | Implemented |
| Help | FAQ/support/privacy links | static/external URLs | No data analysis | Implemented |

## Phase 3+ Core Tables

| Structure | Purpose | Key fields | Used by |
| --- | --- | --- | --- |
| `ScheduleSignal` | Capture arrangements before/after they affect life structure | `title`, `schedule_status`, `date_precision`, `time_precision`, `scene`, `expected_energy_load`, `actual_energy_load`, `feedback_status`, `linked_signal_card_ids_json` | Today, Weekly, Journey |
| `LifeExperimentStrategy` | Explain why one experiment direction was chosen | `target_pattern`, `reason`, `evidence_json`, `expected_change`, `scope`, `do_not_change`, source IDs | Weekly, Journey |
| `LifeExperimentFeedback` | Development-stage feedback for experiments | `happened`, `trigger_context`, `difficulty`, `actual_duration_minutes`, `before_state`, `after_state`, `effect`, `next_adjustment` | Weekly, Journey |
| `Goal` | User-selected target for optional life experiments | `title`, `goal_type`, `period`, `desired_frequency`, `desired_duration_minutes`, `deadline` | Today, Weekly, Journey, Me |
| `GoalPlan` | Local AI-style task breakdown | `minimum_task`, `standard_task`, `full_task`, `frequency`, `time_suggestion`, `adopted` | Today, Weekly |
| `GoalTaskInstance` | Today's optional goal exercise | `goal_id`, `local_date`, `planned_time`, `duration_minutes`, `status`, `schedule_signal_id` | Today |
| `GoalFeedback` | Non-punitive Review & Adjust evidence | `happened`, `effort_level`, `effect`, `comment`, `next_adjustment` | Weekly, Journey |

## Account Restore / New Phone

- The app remains local-first.
- A user can choose Apple sign-in to create a private backup snapshot.
- On a new phone, signing in with the same Apple account can restore the latest
  backup bundle.
- This is not realtime sync. It is snapshot backup/restore.
- Backup bundle now includes Phase 3+ tables: schedules, goals, goal plans,
  goal tasks, goal feedback, experiment strategies, and experiment feedback.
- Deleting the account removes local records, cloud backup snapshots, and the
  Apple-linked Signal Path account. It also clears onboarding state so reopening
  the app behaves like a new user.

## Remaining Release Validation

1. Run TestFlight on a real device and verify EventKit / HealthKit permission
   prompts, denial fallback, and authorized abstract-hint generation.
2. Confirm App Store privacy metadata and review notes mention optional Calendar
   and HealthKit abstract hints.
3. Regenerate real app screenshots for Today, Weekly, Journey, Signal Library,
   and Me after layout fix. Screenshots must show real app pages, not harness-only
   references.
4. Confirm floating bottom navigation does not obscure content or controls on all
   main pages.
