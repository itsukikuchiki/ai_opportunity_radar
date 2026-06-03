# Phase 3 V3F-1A: Signal Library Privacy Evidence / Tests

Status: Engineering accepted.

## Privacy Evidence

Signal Library remains an official curated library:

- Patterns are hardcoded official abstract patterns in `SignalLibraryRepository`.
- No user `raw_text` is read when listing library cards.
- Library cards use broad scenes and frictions only.
- Tests reject obvious raw-text, first-person story, identity, location, company, family-relationship, and event fragments.

Covered by:

- `frontend_flutter/test/core/api/repositories/signal_library_repository_test.dart`
  - `curated library uses official abstract patterns only`
  - `library cards do not contain raw text, stories, or identifiers`

## Save To My Observation Evidence

Saving a pattern creates one personal SignalCard:

- `source_type = library_saved`
- `privacy_level = private`
- `user_confirmation = unconfirmed`
- `raw_payload_json` contains only `library_pattern_id` and abstract pattern metadata
- user raw text is not copied into `raw_text` or `raw_payload_json`
- `included_in_summary`, `included_in_weekly`, and `included_in_journey` remain false by default

Covered by:

- `frontend_flutter/test/core/api/repositories/signal_library_repository_test.dart`
  - `save to my observation creates private library_saved SignalCard`

## Private Action Evidence

User actions are local and private:

- `I also have this` inserts a private local action.
- `Not for me` inserts a private local action.
- `Save to my observation` inserts a private local action and one private SignalCard.
- No public interaction table is created.

Covered by:

- `frontend_flutter/test/core/api/repositories/signal_library_repository_test.dart`
  - `library actions are stored locally as private interactions only`

## UI Copy Evidence

Signal Library UI avoids labels and problem-confirming language:

- Uses "Some people encounter a similar structure..."
- Does not say "you are this kind of person."
- Does not say "confirm you have this problem."
- Simplified Chinese save copy uses "先放进你的观察里."

Covered by:

- `frontend_flutter/test/features/pages/signal_library/signal_library_page_widget_test.dart`
  - `shows privacy-safe official abstract patterns`
  - `saving a pattern uses private low-pressure confirmation`
  - `Chinese copy saves into observation without labeling the user`

## Navigation Evidence

Library is a fifth bottom-tab entry and does not replace Today / Weekly / Journey / Me:

- Existing labels remain visible.
- Tapping Library routes to the Library destination.
- A 320 px wide widget test checks the navigation bar without overflow exceptions.

Covered by:

- `frontend_flutter/test/features/shell/home_shell_navigation_test.dart`
  - `five-tab shell keeps existing tabs and opens Library`

## Release QA Blocker

The Release QA blocker remains open:

- Xcode/CoreSimulator/SPM manual screenshots or recordings are still deferred.
- Engineering tests do not count as manual UI evidence.
