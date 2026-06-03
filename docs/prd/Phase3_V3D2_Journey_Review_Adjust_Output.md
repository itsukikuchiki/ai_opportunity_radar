# Phase 3 V3D-2 Journey Review & Adjust Output

Status: Engineering implementation in progress / V3D-2.

Scope: turn the V3D-1 Journey SignalCard foundation into a low-pressure long-term review. This does not include a large Journey visual redesign.

## 1. Output Structure

Journey now has a lightweight Review & Adjust section:

- one recently repeated life pattern
- one main friction source
- one recovery clue
- one Life Experiment feedback clue
- one gentle next adjustment direction

This section is shown before the older signal-layer/source sections so the user first sees a readable long-term review rather than a category report.

## 2. Low-Pressure Copy Rules

Journey copy should avoid:

- "长期问题"
- "你失败了"
- "必须"
- "应该"
- completion / failure framing
- judgement-report framing

Preferred framing:

- "这段时间，可以先这样看"
- "一个反复出现的生活模式"
- "一个主要消耗来源"
- "一个恢复线索"
- "这个设计有没有帮你省一点力"
- "帮助不明显也只是说明这个设计需要调小一点"

AI-generated Journey output is softened before display. Raw SignalCard text is not modified.

## 3. Experiment Feedback Rules

Experiment feedback is treated as evidence for Review & Adjust, not as habit tracking.

- `skipped`: not failure; "this time can be kept as review context"
- `not_helpful`: not failure; "help was not obvious"
- `adjusted`: useful learning; "adjustment clue"
- missing feedback: does not block Journey output
- feedback summary asks whether the design saved a little effort, not whether the user completed something

## 4. Inclusion Reminder

`included_in_journey` remains governed by V3D-1:

- default false
- eligible used SignalCards can be marked true after Journey snapshot input is built
- true means "used by Journey", not confirmed / high-confidence evidence
- inaccurate / excluded / do_not_analyze / sensitive / sync failed / local draft stay false
- legacy can be true only as `legacy_context`
- unconfirmed can be true only as light observation material

## 5. Fallback Rules

Data-insufficient fallback:

- show a light Journey if there is at least one eligible SignalCard or experiment history
- do not pretend deep pattern certainty

AI failure fallback:

- local fallback returns one pattern, one friction, one recovery clue, and one experiment adjustment
- Today / Weekly / SignalCard / Life Experiment records are not affected

Experiment fallback:

- if no feedback exists, Journey says that this does not block long-term review

## 6. Tests

Covered by:

- `frontend_flutter/test/core/api/repositories/memory_repository_test.dart`
- `frontend_flutter/test/features/pages/memory/memory_page_widget_test.dart`

Test coverage:

- Journey output structure has one pattern / friction / recovery / experiment item
- next gentle adjustment direction is available
- `not_helpful` feedback is not failure wording
- `skipped` feedback is not failure wording
- `adjusted` feedback is framed as learning
- AI pressure words are softened in Journey output
- raw SignalCard text is not softened or overwritten
- data-insufficient / AI failure fallback still returns lightweight Journey
- Journey failure does not remove SignalCard raw input
- Journey page displays Review & Adjust section copy

Commands:

- `flutter test test/core/api/repositories/memory_repository_test.dart test/features/pages/memory/memory_page_widget_test.dart`
- `flutter analyze`
- `flutter test`

Backend pytest is not required for V3D-2 because no backend code is changed in this round.
