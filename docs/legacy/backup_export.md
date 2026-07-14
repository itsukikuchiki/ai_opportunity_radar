# Legacy: Backup / Export

Last updated: 2026-07-05

Backup/export is no longer a user-facing Me/Paywall feature.

Keep lower-level modules until P2-06 because:

- old clients may still call backup/account APIs;
- account deletion may still clean backup rows;
- tests or support tools may use backup bundle code;
- destructive endpoint removal needs a client-version/deprecation plan.

Active UI should not present backup/export/restore as a product capability.
