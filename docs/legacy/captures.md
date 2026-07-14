# Legacy: captures

Last updated: 2026-07-05

`captures` is legacy/raw/audit infrastructure. It is not the active business fact table.

Keep for now because:

- old clients may still call `/api/v1/captures`;
- local legacy rows may need migration into SignalCard;
- raw input audit can be useful for support or recovery.

Active design: `signal_cards` is the user fact table. Any business logic that still treats `captures` as primary should be migrated.
