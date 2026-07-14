# Sync, Privacy, Delete

Last updated: 2026-07-12

## Active Rules

| Area | Rule |
| --- | --- |
| Local save | Save first into local SignalCard/draft state. |
| Sync identity | Use `client_id` / `server_id` through `signal_sync_identity`. |
| Processing state | Store draft/sync/inclusion status in `signal_processing_state`. |
| Analysis policy | Store privacy/inaccurate/exclusion in `signal_analysis_policy`. |
| Eligibility | All summaries and AI routes should use `EligibilityService`. |
| Delete / exclude | Mark upstream snapshots/reflections/candidates stale and trace links inactive. |
| Remote parity | Soft delete / tombstone / restore prevents deleted data from being resurrected by old remote rows. |
| Three-signal gate | Recalculate distinct eligible SignalCards after confirmation, privacy, sync, or deletion changes. |
| Unadopted candidates | Invalidate immediately when sources change; show an inline updating state and regenerate after a short debounce. |
| Adopted history | Do not silently delete an adopted action/experiment when source evidence changes; mark provenance changed. |
| Focus preferences | Multi-value focus is local canonical today; remote array persistence is Target and must not fall back to a different visible selection silently. |

AI/Library `Not accurate` and `Do not add` decisions are zero-write actions.
They create neither a SignalCard nor a private match-feedback record.

Physical deletion of columns, tables, or endpoints requires P2-06 destructive cleanup assessment.
