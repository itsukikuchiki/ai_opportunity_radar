# Phase 3 V3B-1 Acceptance Evidence

Date: 2026-05-29

Status: Engineering accepted.

Scope: Today reads SignalCard as the main data source, adds a basic Diary Timeline, supports SignalCard confirmation/correction, and adds a client-side local draft queue with retry.

## 1. Today Data Source Switched To SignalCard

- Flutter API client: `frontend_flutter/lib/core/api/api_client.dart`
  - Added `patchJson` for SignalCard confirmation.
- Flutter model: `frontend_flutter/lib/core/models/today_models.dart`
  - `RecentSignalModel` now carries `signalCardId`, `localDate`, `timezone`, parsed fields, confirmation, migration state, inclusion flags, and local draft state.
- Flutter repository: `frontend_flutter/lib/core/api/repositories/today_repository.dart`
  - `fetchToday()` reads `/api/v1/captures/recent` when `ApiClient` is available.
  - Remote SignalCards are cached into local `signal_cards`.
  - If remote fetch fails, Today falls back to local SignalCard cache and drafts.
- App wiring: `frontend_flutter/lib/core/di/app_dependencies.dart`
  - `TodayRepository` now receives the shared `ApiClient`.
- Backend response contract:
  - `backend/app/schemas/capture_schema.py`
  - `backend/app/services/capture_service.py`
  - `/api/v1/captures/recent` returns SignalCard fields including `local_date`, parsed fields, confirmation, migration state, and inclusion flags.

## 2. Diary Timeline Basic Version

- UI path: `frontend_flutter/lib/features/pages/today/today_page.dart`
  - Added `Diary Timeline` section below Today Summary.
  - Displays all cached SignalCards from app start / migration.
  - Groups by `RecentSignalModel.localDateKey()`.
  - Uses `local_date` first, then falls back to local `created_at`.
  - Displays raw text, saved AI reply, `created_at`, parsed fields, `legacy`, `migration_status`, `unconfirmed`, and included status chips.

## 3. Confirmation And Correction Writes

- ViewModel path: `frontend_flutter/lib/features/pages/today/today_view_model.dart`
  - Added `confirmSignal()`.
- Repository path: `frontend_flutter/lib/core/api/repositories/today_repository.dart`
  - Added `confirmSignalCard()`.
  - Local write happens first through `LocalCaptureRepository.updateSignalCardConfirmation()`.
  - Remote PATCH follows at `/api/v1/captures/signal-cards/{id}/confirmation`.
- UI path: `frontend_flutter/lib/features/pages/today/today_page.dart`
  - Added actions: `accurate`, `inaccurate`, `edited`, `supplemented`.
  - `edited` and `supplemented` open a dialog and write `user_correction_json`.

## 4. Local Draft Queue And Retry

- Local schema: `frontend_flutter/lib/core/local/local_database.dart`
  - DB version bumped to 7.
  - Added `signal_cards` cache table.
  - Added `signal_card_drafts` retry queue.
- Local repository: `frontend_flutter/lib/core/local/local_capture_repository.dart`
  - `insertLocalDraftSignal()` saves raw input before network.
  - `listPendingDraftRows()` finds pending / failed drafts.
  - `markDraftFailed()` preserves failed draft state.
  - `markDraftSynced()` removes the local draft card when the remote SignalCard is available.
  - `mirrorLegacyCapturesToSignalCards()` mirrors older local captures into SignalCard-shaped rows.
- Remote repository: `frontend_flutter/lib/core/api/repositories/today_repository.dart`
  - `submitCapture()` with `ApiClient` uses save-first local draft, then attempts backend sync.
  - `retryPendingDrafts()` retries pending / failed drafts and caches remote SignalCards.

## 5. Tests

Commands run:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter analyze
flutter test
flutter test test/features/pages/today/today_v3b_manual_evidence_test.dart

cd /Users/yangyang/ai_opportunity_radar/backend
.venv/bin/pytest
```

Results:

- `flutter analyze`: no issues found.
- `flutter test`: `40 passed`.
- `flutter test test/features/pages/today/today_v3b_manual_evidence_test.dart`: `3 passed`.
- Backend pytest: `29 passed`.

V3B-specific Flutter tests:

- `Today 读取远端 SignalCard，并保留 legacy / local_date 状态`
- `Timeline 分组使用 SignalCard local_date，不按 UTC 日期错分`
- `user_confirmation 和 user_correction_json 会先写入本地并同步 PATCH`
- `backend unreachable 时先保存 local draft，retry 后替换为 SignalCard`

Backend contract regression caught and fixed:

- `/api/v1/captures/recent` previously exposed parser `signal_type` through `emotion`, which caused `/api/v1/ai/today-summary` validation failure.
- `CaptureService.list_recent_signal_cards()` now normalizes recent response `emotion` to `positive / negative / mixed / neutral` and `intensity` to `low / medium / high`.

## 6. Screenshot / Recording Status

V3B-1A update:

- Flutter SDK was repaired by resetting `/Users/yangyang/development/flutter` stable to `origin/stable`.
- Flutter now runs as `3.44.0`, Dart now runs as `3.12.0`.
- `frontend_flutter/pubspec.yaml` was updated from `intl: ^0.19.0` to `intl: ^0.20.2` to match the newer `flutter_localizations` pin.
- `flutter analyze` and `flutter test` now complete successfully.
- `today_v3b_manual_evidence_test.dart` now verifies:
  - normal online SignalCard rendering
  - backend-unreachable local draft rendering
  - retry-ready draft status
  - legacy Timeline rendering after scroll
  - local_date grouping
  - accurate / edited confirmation write path
  - saved old `ai_reply` display
- A real UI bug was found and fixed during this pass: the correction dialog disposed its `TextEditingController` before the dialog route was fully removed, which caused Flutter 3.44 to throw `TextEditingController was used after being disposed`.

Attempted simulator UI evidence:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
xcrun simctl boot 791DD8B4-2B1F-4D9A-8CEF-14ED6F91257A
flutter run -d 791DD8B4-2B1F-4D9A-8CEF-14ED6F91257A -t tool/v3b_evidence_app.dart
xcrun simctl io 791DD8B4-2B1F-4D9A-8CEF-14ED6F91257A screenshot /private/tmp/signalpath_v3b_evidence/v3b_evidence_simulator_current.png
xcrun simctl shutdown all
xcrun simctl boot F74BF2DC-C556-402D-ADE8-687D545C251C
flutter run -d F74BF2DC-C556-402D-ADE8-687D545C251C -t tool/v3b_evidence_app.dart
flutter test test/features/pages/today/today_v3b_manual_evidence_test.dart
```

Result:

- The previous `cpuinfo_macos.cc:42` Dart VM crash is resolved.
- The previous `flutter test` version-check / `git fetch --tags` hang is resolved.
- iOS 26.1 and iOS 18.5 simulators can boot.
- `flutter run` now reaches app launch, but fails before the evidence app is visible because Xcode hangs/fails at `xcodebuild -resolvePackageDependencies`.
- A screenshot was produced at `/private/tmp/signalpath_v3b_evidence/v3b_evidence_simulator_current.png`, but it only shows the simulator Apple boot screen, so it is not accepted as Today UI evidence.
- Current remaining blocker for manual screenshot/recording is Xcode/CoreSimulator Swift Package resolution, not Flutter/Dart versioning and not V3B app code.
- Functional UI coverage is backed by widget tests and repository tests until Xcode/CoreSimulator can install and launch the app.

## 7. Archive Decision

V3B-1 is archived as Engineering accepted.

Manual simulator / device screenshots and recordings are deferred to Release QA. They are not considered an app business-code blocker for entering V3B-2, but they remain required before release-level manual UI acceptance.

Release QA blocker to preserve:

- `flutter run -t tool/v3b_evidence_app.dart` hangs/fails at `xcodebuild -resolvePackageDependencies`.
- `CoreSimulatorService connection became invalid`.
- `simdiskimaged crashed or is not responding`.
- The current simulator screenshot only shows the Apple boot logo and is not valid Today UI evidence.
