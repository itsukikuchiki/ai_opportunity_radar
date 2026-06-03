# Phase 3 V3F-2: Library Saved SignalCard Integration

Status: Engineering accepted.

## Goal

V3F-2 confirms that abstract patterns saved from Signal Library enter the user's private observation system safely, without becoming community content, raw diary text, or confirmed evidence by default.

## Display Rule

`library_saved` SignalCards appear in Today / Diary Timeline as Library observations:

- Timeline shows "Saved from Library" / "From Library".
- Pattern title and abstract metadata come from `raw_payload_json`.
- `raw_text` is empty by default and is not displayed as the user's diary text.
- User-supplied context is shown separately as "Your context" after the user edits or supplements the card.

## Inclusion Rule

`library_saved` SignalCards are:

- `privacy_level = private` by default
- `user_confirmation = unconfirmed` by default
- excluded from Today Summary / Weekly / Journey / Energy Budget while unconfirmed
- eligible only after `accurate`, `edited`, or `supplemented`
- excluded after `inaccurate`, `excluded`, `sensitive`, `do_not_analyze`, local draft, or sync failure

Confirmed `library_saved` cards keep a distinct evidence level:

- Weekly: `library_saved_confirmed`
- Journey: `library_saved_confirmed`
- Energy Budget: `library_saved_confirmed`

This means "used by analysis" does not equal native diary evidence.

## Privacy Rule

Saving, supplementing, and confirming a Library card remain private. User supplement text is saved into the personal SignalCard correction payload and is not used to generate shared Library content.

There is no public interaction table or shared pattern generation path in V3F-2.

## Test Evidence

Covered by:

- `frontend_flutter/test/core/api/repositories/signal_library_repository_test.dart`
- `frontend_flutter/test/features/pages/today/today_page_widget_test.dart`
- `frontend_flutter/test/core/api/repositories/weekly_repository_test.dart`
- `frontend_flutter/test/core/api/repositories/memory_repository_test.dart`
- `frontend_flutter/test/core/api/repositories/energy_budget_repository_test.dart`

## Release QA Blocker

The existing Release QA blocker remains open:

- Xcode/CoreSimulator/SPM manual screenshots or recordings are still deferred.
- Engineering tests do not count as manual UI evidence.
