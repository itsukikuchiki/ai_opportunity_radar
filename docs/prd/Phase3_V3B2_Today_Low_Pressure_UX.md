# Phase 3 V3B-2 Today Low-Pressure UX

Date: 2026-05-29

Status: Engineering accepted.

## Scope

V3B-2 starts after V3B-1 Engineering accepted and V3B-1A Toolchain partial fix archived.

This stage is intentionally limited to:

- Today state copy
- Timeline readability
- low-pressure confirmation and sync wording

This stage does not include a large Today visual redesign.

## Release QA Blocker Preserved

Manual screenshot / recording remains a Release QA blocker:

- `flutter run -t tool/v3b_evidence_app.dart` hangs/fails at `xcodebuild -resolvePackageDependencies`.
- `CoreSimulatorService connection became invalid`.
- `simdiskimaged crashed or is not responding`.
- Current simulator screenshots only show the Apple boot logo and are not Today UI evidence.

## First Pass Changes

Files:

- `frontend_flutter/lib/features/pages/today/today_page.dart`
- `frontend_flutter/test/features/pages/today/today_page_widget_test.dart`
- `frontend_flutter/test/features/pages/today/today_v3b_manual_evidence_test.dart`

Changes:

- Renamed Today's current-day section from `Today’s entries` to `Signal inbox`.
- Rewrote current-day subtitle to avoid rigid `0-24` wording and emphasize the user's local date.
- Rewrote Diary Timeline subtitle to say the app keeps everything the user has saved, grouped by local date.
- Rewrote local draft banner from engineering wording to low-pressure wording:
  - old: `local draft(s) saved on this device`
  - new: `saved on this device first. Nothing is lost`
- Replaced `Retry` with `Sync`.
- Replaced raw status chips:
  - `unconfirmed` -> `Not checked yet`
  - `accurate` -> `Looks right`
  - `inaccurate` -> `Not quite`
  - `edited` -> `Adjusted`
  - `supplemented` -> `Added context`
  - `legacy` -> `Imported`
  - `local draft` -> `Saved on device`
  - `sync failed` -> `Waiting to sync`
- Replaced confirmation button copy:
  - `Accurate` -> `Looks right`
  - `Inaccurate` -> `Not quite`
  - `Edit` -> `Adjust`
  - `Add note` -> `Add context`
- Softened common parsed-field labels without changing stored values.

## V3B-2B Status Copy Table

| State | English | Japanese | Simplified Chinese | Traditional Chinese |
| --- | --- | --- | --- | --- |
| Saved on device | Saved on device | 端末に保存済み | 已保存在本机 | 已保存在本機 |
| Waiting to sync | Waiting to sync | 同期待ち | 等待同步 | 等待同步 |
| Synced | Synced | 同期済み | 已同步 | 已同步 |
| Sync failed | Sync needs retry | 同期は再試行待ち | 同步待重试 | 同步待重試 |
| Not checked yet | Not checked yet | 未確認 | 还没确认 | 還沒確認 |
| Imported | Imported | 移行済み | 旧记录已导入 | 舊記錄已導入 |
| Looks right | Looks right | 合っていそう | 是准的 | 是準的 |
| Not quite | Not quite | 少し違う | 不太准 | 不太準 |
| Adjust | Adjust | 調整 | 改一下 | 改一下 |
| Add context | Add context | 少し補足 | 补一点 | 補一點 |

## Empty And Failure Copy

| Case | English | Japanese | Simplified Chinese | Traditional Chinese |
| --- | --- | --- | --- | --- |
| No records today | No entries yet today | 今日はまだ記録がありません | 今天还没有记录 | 今天還沒有記錄 |
| Local saved but not synced | item(s) are saved on this device first. Nothing is lost; sync can happen when the connection is back. | 件はまずこの端末に保存されています。消えません。接続後に同期できます。 | 条内容已先保存在这台设备上。不会丢，网络恢复后可以同步。 | 條內容已先保存在這台裝置上。不會丟，網路恢復後可以同步。 |
| Sync failed but data is safe | Sync needs retry + Saved on device | 同期は再試行待ち + 端末に保存済み | 同步待重试 + 已保存在本机 | 同步待重試 + 已保存在本機 |
| AI not organized yet | AI has not organized this yet. Your original note is already saved. | AI はまだ整理していませんが、元の記録は保存されています。 | AI 还没整理这条，但你的原文已经保存。 | AI 還沒整理這條，但你的原文已經保存。 |
| Old record imported | Imported | 移行済み | 旧记录已导入 | 舊記錄已導入 |
| No AI reply fallback | AI has not organized this yet. Your original note is already saved. | AI はまだ整理していませんが、元の記録は保存されています。 | AI 还没整理这条，但你的原文已经保存。 | AI 還沒整理這條，但你的原文已經保存。 |

## Status Combination Review

| Combination | Display rule | User interpretation |
| --- | --- | --- |
| pending + unconfirmed | `Saved on device` + `Sync needs retry` + `Not checked yet` | It is saved locally, not lost, and optional confirmation can wait. |
| imported + unconfirmed | `Imported` + `Not checked yet` | This is an old record brought forward, not an error. |
| synced + edited | `Synced` + `Adjusted` | The record has synced and the user's correction is reflected. |
| sync failed + saved on device | `Saved on device` + `Sync needs retry` | Sync needs another attempt, but the raw input is safe. |

## V3B-2B Follow-Up Changes

Files:

- `frontend_flutter/lib/features/pages/today/today_page.dart`
- `frontend_flutter/test/helpers/widget_test_helpers.dart`
- `frontend_flutter/test/features/pages/today/today_v3b_manual_evidence_test.dart`

Changes:

- Added explicit `Synced` state for remote/synced SignalCards.
- Renamed sync-failure chip to low-pressure `Sync needs retry`.
- Kept local failure combinations as `Saved on device` + `Sync needs retry` instead of a single alarming error state.
- Added low-priority AI fallback text when `acknowledgement` is missing:
  - `AI has not organized this yet. Your original note is already saved.`
- Added widget test locale support for English, Japanese, Simplified Chinese, and Traditional Chinese.
- Added V3B-2B tests for status chips, confirmation button copy, draft/retry copy, imported legacy copy, and no-AI-reply fallback.

## Acceptance Notes

V3B-2 should continue to preserve the V3B red lines:

- user input remains visible
- old AI reply is not regenerated
- local drafts do not create failure/blame language
- confirmation and correction still write to the same underlying values
- Timeline still groups by `local_date`

## Verification

First pass commands:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/features/pages/today test/core/api/repositories/today_repository_test.dart
```

Result:

- `14 passed`.

V3B-2B commands:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter test test/features/pages/today test/core/api/repositories/today_repository_test.dart
flutter analyze
flutter test
```

Results:

- Today + TodayRepository subset: `16 passed`.
- `flutter analyze`: no issues found.
- `flutter test`: `42 passed`.

Coverage:

- status chip display
- confirmation button copy
- draft / retry copy
- legacy imported copy
- four-language Today status copy
