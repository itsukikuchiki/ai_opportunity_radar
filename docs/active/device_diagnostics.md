# P2.1-19 Logs And Diagnostics

Status: prepared for real-device testing.

Primary internal entry:

- Internal / staging builds: `/debug/trace`
- Flutter page: `frontend_flutter/lib/features/debug/debug_trace_page.dart`
- Build gate: `BuildEnvironment.debugToolsVisible`
- Internal build flags: `SIGNALPATH_ENABLE_DEBUG_TOOLS=true`,
  `SIGNALPATH_ENABLE_PIPELINE_LOGS=true`

## Diagnostic Coverage

| Need | Status | Where to check |
| --- | --- | --- |
| 1. fallback counters | Ready | `/debug/trace` -> `Legacy fallback counters`. Reset, reproduce, refresh. Source: `LegacyFallbackMonitor`. |
| 2. `pipeline_runs` | Ready | `/debug/trace` -> `Pipeline runs`. Shows pipeline type, source, status, hashes, retry/error state. |
| 3. `trace_links` | Ready | `/debug/trace` -> `Trace links`. Shows source, target, relation, status, metadata. |
| 4. reflection stale reason | Ready | `/debug/trace` -> `Reflection sources`. Shows `dirty`, `is_stale`, `stale_reason`, prompt/model/pipeline versions. |
| 5. snapshot `source_hash` | Ready | `/debug/trace` -> `Snapshot source hashes`. Shows weekly/journey source hash, dirty/stale state, pipeline version. |
| 6. `sync_identity` | Ready | `/debug/trace` -> `Sync identity`. Shows `client_id`, `server_id`, `local_signal_id`, sync status, timestamps. |
| 7. tombstone state | Ready | `/debug/trace` -> `Tombstone state`. Supports lookup by signal id, signal_card_id, client_id, or server_id even when `signal_cards` no longer has the row. |
| 8. legacy endpoint telemetry | Backend ready, live staging still needs DB check | Backend table `legacy_endpoint_telemetry`; tests cover captures, backup/account/auth split, opportunities, and `/api/v1/ai/deep-weekly`. See `docs/active/staging_backend_confirmation.md`. |
| 9. crash logs | External device tooling | Use Xcode Devices and Simulators / Organizer crash reports, or macOS Console filtered by app process. No product UI should expose crash logs. |
| 10. network failure logs | Ready through local state + request ID | Every Flutter API call sends `X-Request-Id`; backend echoes it. `/debug/trace` shows state transitions while the privacy-safe global logger records request ID, error type, event ID, and fingerprint only. |
| 11. initialization failure | Ready | Startup failures render a localized retry page with a safe reference code. Raw exception messages, paths, stack traces, HTTP bodies, and user text are never shown. |

## Privacy-Safe Global Error Contract

Flutter and backend unhandled exceptions use the same diagnostic boundary:

- allowed: event/reference ID, operation, exception type, fingerprint, request
  ID, fatal flag, and timestamp;
- forbidden: exception message, request/response body, Signal text, diary text,
  account/session tokens, local paths, raw stack trace, StoreKit details, and
  transaction identifiers;
- Flutter retains at most 100 safe in-memory records and sends no telemetry by
  itself;
- backend 500 responses are generic and include only a safe error code plus the
  request ID;
- callers may share the visible startup reference code or `X-Request-Id` with
  support to correlate device and backend logs.

Automated checks:

```sh
cd frontend_flutter
flutter test \
  test/core/diagnostics/privacy_safe_logger_test.dart \
  test/core/api/api_client_observability_test.dart \
  test/features/system/initialization_failure_page_widget_test.dart \
  test/core/purchases/purchase_controller_test.dart

cd ..
python3 -m pytest backend/tests/test_request_observability.py -q
```

## Real-Device Workflow

1. Install an Internal or Staging build created with debug tools enabled.
2. Open `/debug/trace`.
3. Reset fallback counters.
4. Reproduce the suspect flow.
5. Search by `signal_cards.id`, `signal_card_id`, `client_id`, or `server_id`.
6. Capture screenshots of:
   - Legacy fallback counters
   - Signal
   - Sync identity
   - Tombstone state
   - Snapshot source hashes
   - Trace links
   - Reflection sources
   - Pipeline runs
7. For server legacy telemetry, query staging `legacy_endpoint_telemetry` by
   counter name and time window.
8. For crashes or networking failures, collect safe event/reference IDs and
   request IDs first. If external tooling contains a raw payload, do not attach
   it until user content and credentials have been removed.

## Backend Telemetry Query Examples

```sql
SELECT counter_name, endpoint, client_version, platform, COUNT(*) AS calls
FROM legacy_endpoint_telemetry
WHERE created_at >= NOW() - INTERVAL '24 hours'
GROUP BY counter_name, endpoint, client_version, platform
ORDER BY calls DESC;
```

```sql
SELECT *
FROM legacy_endpoint_telemetry
WHERE counter_name = 'legacy_deep_weekly_endpoint_call_count'
ORDER BY created_at DESC
LIMIT 20;
```

Telemetry intentionally stores hashes and client metadata only. It must not store
raw Signal text.

## Remaining External Checks

- Confirm live staging DB has the `legacy_endpoint_telemetry` table after
  switching Railway to `Environment: staging`.
- Confirm crash collection route for TestFlight/internal builds before wider QA.
- Confirm request-ID correlation between one staging response and the backend
  privacy-safe exception log; do not add raw payloads to app-visible debug UI.
