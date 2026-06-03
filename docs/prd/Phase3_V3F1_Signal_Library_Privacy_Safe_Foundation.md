# Phase 3 V3F-1: Signal Library Privacy-Safe Foundation

Status: Engineering accepted.

## Goal

V3F-1 establishes Signal Library as an official curated pattern library. It is not a community, recommendation feed, or user-story sharing surface.

The library exists to help users recognize abstract life structures with low pressure, while keeping every user interaction private.

## Privacy Boundary

- Signal Library uses only official curated abstract patterns.
- User `raw_text` is never used to create shared library content.
- User-specific stories are never displayed.
- Library cards must not include identifiable people, places, workplaces, family relationships, or specific events.
- `I also have this`, `Save to my observation`, and `Not for me` are private local actions.
- No public interaction counts, likes, popularity ranking, or community metadata are produced.

## Library Pattern Model

| Field | Purpose |
| --- | --- |
| `id` | Stable official pattern id |
| `title` | Short abstract title |
| `abstract_pattern` | Non-identifying pattern description |
| `common_scenes` | Broad scene tags only |
| `common_frictions` | Broad friction tags only |
| `energy_load_hint` | Lightweight energy hint |
| `possible_positive_signal` | Possible recovery or positive clue |
| `gentle_reflection` | Low-pressure reflection copy |
| `suggested_small_experiment` | Optional small experiment |
| `language` | Pattern language |
| `created_at` / `updated_at` | Curated content timestamps |

## Initial Official Curated Patterns

- over-scheduled weeks
- recovery debt
- attention switching fatigue
- unclear expectation relationship friction
- late-night compensation behavior
- weak positive signals
- boundary fatigue
- small freedom / connection / creative energy

## Save To My Observation

Saving a pattern creates a personal SignalCard:

- `source_type = library_saved`
- `privacy_level = private`
- `user_confirmation = unconfirmed`
- `raw_text` uses only an official library title seed, not another user's content
- `raw_payload_json` stores `library_pattern_id` and abstract pattern metadata
- `included_in_summary = false`
- `included_in_weekly = false`
- `included_in_journey = false`

The UX copy says the pattern was saved privately into observations. It does not say the user has confirmed a problem.

## UX Rules

- Do not say "you are this kind of person."
- Do not label the user.
- Use "Some people encounter a similar structure..."
- After save, express it as "Saved privately into your observations" / "先放进你的观察里."
- Pattern actions are optional and private.

## Evidence Rules

Signal Library patterns are not evidence about the user until they are saved into the user's private observations. Saved library cards remain `unconfirmed` until the user explicitly confirms or edits them.

## Release QA Blocker

The existing Release QA blocker remains open:

- Xcode/CoreSimulator/SPM prevents manual UI screenshots or recordings.
- V3F-1 engineering implementation must not be marked as manual UI QA complete until screenshots or recordings are captured later.
