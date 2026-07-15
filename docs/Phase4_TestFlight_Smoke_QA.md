# Phase 4 TestFlight Smoke QA

Date: 2026-07-15

Last reconciled with the current source, final design, automated tests, and a
read-only App Store Connect API check: 2026-07-15.

> Plural candidates, zero-to-many adoption, and real per-object `X/7` progress
> are implemented engineering baseline, not pending implementation. They remain
> pending TestFlight / real-device regression. System Calendar is outside this
> QA round; any Calendar permission sheet is a failure. No new archive or
> upload is implied by this document update.

Scope: prepare the next major TestFlight validation package for Phase 3+ / Phase 4 platform QA. This version is for platform validation first, not production release sign-off.

## Current and Next Version Baseline

| Field | Value |
| --- | --- |
| Current repository version | `4.0.0+13` |
| Latest ASC build | `4.0.0 (12)`; `VALID`, not expired |
| Next unused ASC build number | `13`, confirmed by read-only API on 2026-07-15 |
| Next current-worktree archive | `4.0.0 (13)`, user-authorized QA showcase build |
| ASC version record | `4.0.0`; `PREPARE_FOR_SUBMISSION` |
| Bundle ID | jp.sunrise.signalpath |
| Purpose | TestFlight platform validation |
| Production ready | No |

Build `12` already exists in ASC. The current worktree must not be archived or
uploaded as build `11` or `12`; this QA showcase upload uses build `13`.

## Current Baseline Status

| Area | Status |
| --- | --- |
| Current source version | `4.0.0+13` |
| Latest ASC build in the `4.0.0` train | Build `12`, `VALID`, uploaded 2026-07-14 |
| Latest automated baseline | Pending final build-13 full-suite reconciliation; backend 89 passed / 2 PostgreSQL-only skips |
| Current-worktree IPA | Build `13` QA showcase archive authorized; upload status recorded after delivery |
| Candidate/progress engineering baseline | Implemented; automated coverage passed |
| Current TestFlight real-device regression | Pending |
| Platform QA | Open |
| Production ready | No |

## Version Sources

| Area | Required value | Status |
| --- | --- | --- |
| `frontend_flutter/pubspec.yaml` | `version: 4.0.0+13` | Current source truth |
| iOS `CFBundleShortVersionString` | `$(FLUTTER_BUILD_NAME)` -> `4.0.0` | Derived from Flutter build |
| iOS `CFBundleVersion` | `$(FLUTTER_BUILD_NUMBER)` -> `13` | Derived from Flutter build |
| Runner Release `CURRENT_PROJECT_VERSION` | `$(FLUTTER_BUILD_NUMBER)` | Already configured |
| Fastlane / build scripts | No repo Fastfile found | Not applicable |
| App Store Connect version record | `4.0.0` | API confirmed; `PREPARE_FOR_SUBMISSION` |

## App Store Connect Preflight

Read-only API confirmation on 2026-07-15:

| Check | Confirmed result | Release status |
| --- | --- | --- |
| Highest uploaded build in `4.0.0` | `12`, `VALID`, not expired | Confirmed |
| Next unused build number | `13` | Confirmed; reserved for this user-requested QA showcase archive |
| Monthly product `jp.sunrise.signalpath.pro.monthly` | `APPROVED`, `ONE_MONTH` | Confirmed |
| Yearly product `jp.sunrise.signalpath.pro.yearly` | `APPROVED`, `ONE_YEAR` | Confirmed |
| Monthly product localizations | `en-US`, `ja`, `zh-Hant` approved | **`zh-Hans` missing in ASC; add before release** |
| Yearly product localizations | `en-US`, `ja`, `zh-Hant` approved | **`zh-Hans` missing in ASC; add before release** |
| Subscription group localizations | `en-US`, `ja`, `zh-Hant` approved | **`zh-Hans` missing in ASC; add before release** |
| App version `4.0.0` metadata | `ja`, `en-US`, `zh-Hans`, `zh-Hant`; description, keywords, and support URL present | Confirmed structurally; final copy still needs human review |
| Sandbox testers | One tester exists | Existence confirmed; sign-in, storefront, renewal/reset state, and purchase history require manual ASC/device check |
| Build `11` internal tester-group visibility | Read-only build relationship query was not authorized | Confirm manually in ASC/TestFlight before device QA |
| TestFlight product discovery | Monthly and yearly returned by StoreKit in the TestFlight Sandbox | Pending real-device confirmation |

Do not store a Sandbox tester password in this repository or QA document. Record
only a masked alias, storefront, and the date the account was manually verified.

The repository's local StoreKit fixture contains four-language product copy, but
that fixture is not ASC evidence. The missing `zh-Hans` subscription and group
localizations above are therefore an external release-preflight gap.

## Current ASC Build Evidence - `4.0.0 (12)`

```text
Marketing version: 4.0.0
Build number: 12
Uploaded: 2026-07-14
Processing state: VALID
Expired: false
Next unused build: 13
```

This proves the ASC train state only. It does not prove that unarchived current
worktree changes are present in build `12`.

## Historical Delivery Evidence

The following build `5`, `4`, and `1` records are retained as historical upload
evidence only. They are not the current QA target and do not cover later product
or data-flow changes.

### `4.0.0 (5)` Build / Upload Result

Historical ASC version creation result:

```text
HTTP 201
App Store version id: 7b5d5c8b-2cdf-49d7-8537-23658de089a8
Version: 4.0.0
State: PREPARE_FOR_SUBMISSION
Release type: AFTER_APPROVAL
```

Latest icon refinement validation package generated on 2026-06-21:

```text
flutter analyze: passed
git diff --check: passed
AppIcon PNG validation: RGB / no alpha
```

Build result:

```text
Version Number: 4.0.0
Build Number: 5
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload / TestFlight result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 20f7f71a-eff8-4692-a3e0-1ec618d2affa
Processing state: VALID
Internal group link: HTTP 204
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
```

Icon update note:

```text
The AppIcon master and AppIcon.appiconset assets were regenerated to remove
the visible white outer ring on SpringBoard. The icon artwork now fills the
iOS rounded icon tile more fully and includes a subtle glossy highlight.
```

### `4.0.0 (4)` Build / Upload Result

Latest validation package generated on 2026-06-21:

```text
flutter clean: passed
flutter pub get: passed
flutter analyze: passed
flutter test --no-pub: 144 passed
backend python3 -m pytest: 33 passed
git diff --check: passed
```

Build result:

```text
Version Number: 4.0.0
Build Number: 4
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload / TestFlight result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 01e66554-278e-4458-b989-90b63d889394
Processing state: VALID
Internal group link: HTTP 204
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
```

### `4.0.0 (1)` Build / Upload Result

Engineering validation was rerun for the `4.0.0` package:

```text
flutter clean: passed
flutter pub get: passed
flutter analyze: passed
flutter test --no-pub: 134 passed
backend python3 -m pytest: 33 passed
git diff --check: passed
```

Build result:

```text
Version Number: 4.0.0
Build Number: 1
Display Name: Signal Path
Deployment Target: 13.0
Bundle Identifier: jp.sunrise.signalpath
IPA: frontend_flutter/build/ios/ipa/SignalPath.ipa
```

Upload result:

```text
UPLOAD SUCCEEDED with no errors
Delivery UUID / build id: 409a8c43-015d-4952-8625-e15ab3937e8f
Processing state: VALID
```

Upload note:

```text
The first upload attempt failed because Apple required
NSHealthUpdateUsageDescription. This was fixed in Info.plist and the IPA was
rebuilt before the successful upload.
```

## TestFlight Internal Distribution Path

Use the corrected App Store Connect API relationship path, not `fastlane pilot distribute --groups`.

Known groups:

| Group | ID | Type |
| --- | --- | --- |
| Signal Path Internal Testers | `da65b43f-8a52-4152-b1fb-1251d03e153f` | Internal |
| Signal Path External Testers | `df83a0c7-0dc1-42ec-8031-ba75e450bee5` | External |

After uploading a new `4.0.0` build, link the build to the internal group:

```text
POST /v1/betaGroups/da65b43f-8a52-4152-b1fb-1251d03e153f/relationships/builds
data: [{ type: "builds", id: "<4.0.0 build id>" }]
```

Historical build `1` link result:

```text
Build id: 409a8c43-015d-4952-8625-e15ab3937e8f
Internal group: Signal Path Internal Testers
Internal group id: da65b43f-8a52-4152-b1fb-1251d03e153f
Link response: HTTP 204
Verification: build appears in internal group builds list, processingState VALID
```

Do not use:

```bash
fastlane pilot distribute --groups "Signal Path Internal Testers"
```

Reason: in this fastlane version, `--groups` is tied to external tester distribution behavior and can trigger beta review submission.

## Required TestFlight Smoke QA

Do not mark Platform QA as passed until these are verified on TestFlight / real device:

Before starting, record the exact installed build. Build `12` is the current ASC
snapshot. Validation of this current worktree uses the user-authorized QA
showcase build `13`.

| Scenario | Status |
| --- | --- |
| Install and record the exact TestFlight build (`13` for this QA showcase package) | Pending real-device QA |
| First fresh launch opens Onboarding page 1 without a white Flutter frame | Pending |
| Onboarding page 1: Record life signals + icon background | Pending |
| Onboarding page 2: Weekly + Life Experiment preview + icon background | Pending |
| Onboarding page 3: Journey + Pro depth preview + icon background | Pending |
| Onboarding page 4: focus-domain multi-select; Start persists choices into Me | Pending |
| Today dynamic hero is compact, useful, and neutral before same-day evidence exists | Pending |
| Today text input saves one SignalCard | Pending |
| Voice and state “Skip for now” close without saving a draft or timeline item | Pending |
| State optional note uses “补一句” (“Add a sentence”) and remains inside the SignalCard chain | Pending |
| AI prediction has Accurate / Somewhat / Not accurate; Accurate and Somewhat use the current direct-add flow, while Not accurate adds nothing | Pending |
| Signal Library cards expose Accurate / Somewhat / Not accurate directly without a popup and create no Small Action / Observation / Experiment peer item | Pending |
| Small Action stays at neutral `X/3` readiness before three eligible same-day signals | Implemented + automated passed; pending real-device QA |
| Weekly experiment candidates stay at neutral `X/3` readiness before three eligible same-week signals | Implemented + automated passed; pending real-device QA |
| Dedicated Small Action candidate page shows up to three choices and supports zero-to-many adoption | Implemented + automated passed; pending real-device QA |
| Weekly opens the dedicated Small Experiment candidate page rather than the Life Experiment archive | Implemented + automated passed; pending real-device QA |
| Dedicated Small Experiment candidate page shows up to three choices and supports zero-to-many adoption | Implemented + automated passed; pending real-device QA |
| Adopted action and experiment progress grids accept daily feedback and show independent, date-deduplicated `X/7` | Implemented + automated passed; pending real-device QA |
| Multiple same-day feedback records remain in history; the last valid item/local-date record determines that day's cell | Implemented + automated passed; pending real-device QA |
| MicroAction progress starts on adoption day; action and experiment progress never borrow from each other | Implemented + automated passed; pending real-device QA |
| Today shows at most three adopted actions and three current experiments; overflow enters “View all” | Implemented + automated passed; pending real-device QA |
| Today never shows the next-week forming/candidate card | Implemented baseline; pending real-device QA |
| Focus, feedback, Health abstraction, or source SignalCard change immediately refreshes unadopted candidates in place without changing adopted items | Implemented + automated passed; pending real-device QA |
| Deleted/changed candidate source keeps adopted item and shows “source changed” | Implemented baseline; pending real-device QA |
| Weekly shows AI read, signal distribution, behavior pattern, Energy Budget, action review, current experiment result, and next-week experiment | Pending |
| Weekly standard/deep report remains neutral before three eligible current-week SignalCards and appears at `3/3` | Implemented baseline; pending real-device QA |
| Journey free report remains neutral before 7 eligible SignalCards across 3 local dates | Implemented baseline; pending real-device QA |
| Journey shows hero, track overview, observations, monthly fragments, in-app SignalCard local-date grid, life curve, and gentle review from real data | Pending |
| Journey Pro L3 gate requires 14 eligible SignalCards across 7 local dates and 2 local Monday-Sunday weeks in the latest 28 local dates | Implemented + automated passed; pending real-device QA |
| Journey Pro L3 entitlement gate, two-week factual comparison, existing Journey synthesis, raw evidence, and real-SignalCard follow-up | Implemented baseline; pending real-device QA |
| Independent versioned 28-day interpretive AI generator | Target only; excluded from this candidate unless separately implemented |
| Main tabs use Today-based typography, card density, content padding, and safe-area clearance on compact/regular/large phones | Pending |
| Diary timeline uses Today density and exposes only Signal / Small Action / Small Experiment filters | Pending |
| Today has no next-week experiment card and no oversized trailing blank area | Pending |
| Cross-page refresh is visible after recording, adopting, editing feedback, changing focus, or changing entitlement | Pending |
| Today timeline L1 AI response acknowledges emotion and gives only light feedback; Pro chat preserves this boundary | Pending |
| AI failure still saves raw input | Pending |
| Quota exceeded still allows recording | Pending |
| Monthly Pro product is returned and can be purchased in TestFlight Sandbox | ASC product approved; pending real-device purchase |
| Yearly Pro product is returned and can be purchased in TestFlight Sandbox | ASC product approved; pending real-device purchase |
| Subscription/product copy is correct in `en-US`, `ja`, `zh-Hans`, and `zh-Hant` | **Blocked: `zh-Hans` missing for monthly, yearly, and subscription group in ASC** |
| Restore Purchase with an active subscription | **Blocker reopened; Pending** |
| Restore Purchase correctly explains TestFlight Sandbox versus App Store Production isolation | Pending |
| Restore fallback waits for delayed restored transactions and produces an actionable error on failure | Pending |
| Pro entitlement unlocks UI / quota | Pending |
| One Sandbox tester can sign in; storefront and renewal/reset state are recorded without storing its password | Account exists in ASC; manual/device verification pending |
| Delete account clears local app/account/onboarding state | Pending |
| No system Calendar user entry or Calendar permission prompt appears anywhere | Required; any Calendar prompt is a failure |
| HealthKit read-only permission denied / authorized / revoked paths stay safe and show abstract recovery only | Pending |
| Keyboard avoids composer and sheets | Pending |
| Floating bottom nav does not cover controls | Pending |
| Dynamic Island / safe area check | Pending |
| `en`, `zh-Hans`, `zh-Hant`, and `ja` device-language pass | Pending |
| 1.3x text scale, minimum 44pt hit targets, and VoiceOver order/semantics pass | Pending |
| Real-device screenshot evidence | Pending |

## Exit Criteria

Phase 4 Platform QA can move to `Passed` only when:

1. The exact candidate build is recorded and is visible/installable in
   TestFlight for internal testers. Current-worktree validation uses build `13`,
   never a reused build `11` or `12`.
2. All implemented No.1–28 flows above are verified. Target-only work is either
   excluded from the candidate or separately implemented and tested.
3. `zh-Hans` monthly, yearly, and subscription-group localizations are added in
   ASC; four-language product copy is checked on device.
4. Monthly/yearly TestFlight Sandbox purchase, Restore Purchase, delayed
   transaction fallback, and entitlement propagation are verified in the same
   StoreKit environment.
5. The Sandbox tester's sign-in/storefront/reset state is manually confirmed;
   no password is stored in evidence.
6. No Calendar permission sheet appears. HealthKit read-only denied,
   authorized, and revoked paths remain safe.
7. Main-tab/secondary-page UI, four languages, 1.3x text, 44pt hit targets, and
   VoiceOver semantics pass on real device.
8. Evidence screenshots or recordings are saved.

Until then:

- Current engineering/automated validation is `Passed` for the recorded checks.
- Existing build `12` may validate only its uploaded snapshot, after internal
  tester visibility is confirmed.
- Current-worktree TestFlight readiness remains `No` until build `13` is
  uploaded, processed, assigned to the internal group, and its exact contents
  are recorded.
- Platform QA remains `Open`.
- Production ready remains `No`.
