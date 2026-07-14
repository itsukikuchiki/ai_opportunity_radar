# Historical Delivery And QA Evidence Index

Last updated: 2026-07-12

Nothing in `docs/prd/` is a current product design. The sole final design is [`../active/app_design.md`](../active/app_design.md), and the canonical data contract is [`../active/data_flow.md`](../active/data_flow.md).

Files remain here only when they preserve useful implementation decisions, migration history, automated/manual QA evidence, release gates, or rollback context. Their old page hierarchy, product grain, timing gates, Schedule/Goal flows, embedded experiment flow, and visual locks are superseded.

## Current Sources

| Concern | Current document |
| --- | --- |
| Final product and all page responsibilities | [`../active/app_design.md`](../active/app_design.md) |
| End-to-end data flow and implementation gaps | [`../active/data_flow.md`](../active/data_flow.md) |
| AI levels and orchestration | [`../active/ai_orchestration.md`](../active/ai_orchestration.md) |
| Main-tab visual standard | [`../active/main_tab_ui_standard.md`](../active/main_tab_ui_standard.md) |
| Purchase and entitlement | [`../active/purchase_entitlement.md`](../active/purchase_entitlement.md) |
| Current documentation governance | [`../active/README.md`](../active/README.md) |

## Retained Evidence Families

- `Phase3_V3A*` through `Phase3_V3G*`: historical implementation and acceptance evidence for save-first capture, Weekly/Journey, Energy Budget, Signal Library, and optional abstract Calendar/Health hints.
- `Phase3_Closeout*`: historical Phase 3 closeout and rollback evidence.
- `ReleaseQA_*`: historical release, visual, purchase, signing, TestFlight, and App Store submission evidence.

These files may explain why code or migrations exist, but they cannot be cited as proof that the current final design is implemented or that a reopened TestFlight defect has passed.

## Conflict Rule

Use: latest confirmed user decision → final app design → canonical data flow/scoped technical contract → current QA result → historical evidence.

When a retained record links to a deleted design draft, replace that link with the final app design rather than recreating the old draft.
