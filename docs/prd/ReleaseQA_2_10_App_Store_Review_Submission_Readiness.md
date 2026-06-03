# ReleaseQA-2.10: App Store Review Submission Readiness

Status: App Review submitted successfully for `3.0.0 (3)`.

Candidate:

| Item | Value |
| --- | --- |
| App | Signal Path |
| Bundle ID | `jp.sunrise.signalpath` |
| Version | `3.0.0` |
| Candidate build | `3` |
| Visual baseline | `ReleaseQA_2_7H_Visual_Direction_Lock.md` |

Scope: prepare App Store Review submission for version `3.0.0 (3)` after TestFlight real-device QA. This stage does not add features, does not change UI, and does not change purchase, Pro, quota, privacy, EventKit / HealthKit, or Phase 3 data-chain logic.

## 1. 2.7H Visual Lock

ReleaseQA-2.7H remains the only visual baseline.

Do not proactively change:

- App Icon
- Splash
- LaunchImage
- main color system
- main background direction
- UI structure

Allowed changes after this point are only release-blocking bug fixes or small pixel polish for spacing, alignment, button state, text overflow, multilingual wrapping, and screenshot polish.

## 2. ReleaseQA-2.9 Real-Device TestFlight Final Result

Source: user confirmed that TestFlight real-device testing has completed before entering ReleaseQA-2.10. Codex did not independently operate the real device in this step.

| Scenario | Final result |
| --- | --- |
| TestFlight installation | Passed per user confirmation |
| First launch | Passed per user confirmation |
| Native LaunchScreen | Passed per user confirmation |
| Flutter Splash | Passed per user confirmation |
| Onboarding 3 pages | Passed per user confirmation |
| Today page entry | Passed per user confirmation |
| Today save | Passed per user confirmation |
| Weekly Day 0 state | Passed per user confirmation |
| Journey Day 0 state | Passed per user confirmation |
| Day 0 eligible signal saved | Passed per user confirmation |
| Weekly Day 1 / next local day state | Passed per user confirmation |
| Journey Day 1 / next local day state | Passed per user confirmation |
| Weekly 7 active app days state | Passed per user confirmation |
| AI failure preserves raw input | Passed per user confirmation |
| Quota exceeded still allows recording | Passed per user confirmation |
| Monthly Pro purchase | Passed per user confirmation |
| Yearly Pro purchase | Passed per user confirmation |
| Restore purchase | Passed per user confirmation |
| Pro entitlement activation | Passed per user confirmation |
| Free quota display | Passed per user confirmation |
| Pro quota display | Passed per user confirmation |

Blocker summary:

- Blockers: none reported by user after TestFlight real-device testing.
- Non-blockers: Flutter / iOS Swift Package + CocoaPods advisory remains non-blocking.
- Deferrable items: real EventKit permission integration and real HealthKit permission integration remain future advanced enhancements; current shipped build uses abstract hint prototypes / internal signal fallback.

Release decision:

- Based on user-confirmed TestFlight real-device QA with no reported blockers, the app can proceed to App Store Review preparation.
- Do not mark App Review submission complete until App Store Connect confirms the submission.

## 3. App Store Connect Metadata Readiness

Metadata should be confirmed in App Store Connect before submission.

| Field | Required readiness |
| --- | --- |
| App name | Signal Path |
| Subtitle | Confirm populated in each supported localization |
| Description | Confirm current `3.0.0` / Phase 3 description is populated |
| Keywords | Confirm populated and localization-safe |
| Category | Confirm selected |
| Support URL | `https://itsukikuchiki.github.io/signalpath-support/` |
| Privacy policy URL | `https://itsukikuchiki.github.io/signalpath-support/` |
| Age rating | Confirm completed |
| Screenshots | Confirm Product Review screenshots are attached |
| App Privacy | Confirm data collection / non-collection answers are current |
| Availability | Confirm intended territories |
| Release option | Recommended: release automatically after approval |

Current status:

- `fastlane run latest_testflight_build_number` confirmed `3.0.0 (3)` as the latest TestFlight build for `jp.sunrise.signalpath`.
- `fastlane precheck` passed for App Store metadata with in-app purchase checking disabled, because Fastlane cannot precheck IAP with App Store Connect API key auth.
- `fastlane deliver submit_build` selected build `3.0.0 (3)` successfully.
- Release notes were uploaded for `en-US`, `zh-Hans`, `zh-Hant`, and `ja`.
- App Review notes were uploaded.
- Missing required metadata fields reported by the first submit attempt were:
  - `description`
  - `keywords`
  - `supportUrl`
- These fields were then uploaded through `/private/tmp/signalpath_appstore_metadata` for all four supported localizations.
- Current Product Review screenshots reflecting the locked 2.7H UI were uploaded through `/private/tmp/signalpath_appstore_screenshots`.
- Final App Review submission was accepted after App Store Connect finished processing screenshots.

Screenshot note:

- Screenshots were built from the locked Product Review set at `/private/tmp/signalpath_product_review_2_7h`.
- They reflect the UI changes in the 2.7H visual baseline: cold white / pale blue-gray UI, Today signal flow, Weekly, Journey, Signal Library, and Me / Pro surfaces.
- Screenshots were resized to `1290x2796` for App Store upload.
- Do not submit with older screenshots that still show the previous warm ivory / coral direction or old Signal Library copy.

## 4. IAP / Subscription Review Readiness

Products expected in the app:

| Product | Product ID | Display price baseline | Type |
| --- | --- | --- | --- |
| Monthly Pro | `jp.sunrise.signalpath.pro.monthly` | `$0.99 / month` | Auto-renewable subscription |
| Yearly Pro | `jp.sunrise.signalpath.pro.yearly` | `$9.99 / year` | Auto-renewable subscription |

Required checks before submission:

- Monthly Pro product ID, pricing, availability, and localization are complete.
- Yearly Pro product ID, pricing, availability, and localization are complete.
- Subscription group is configured.
- Paid Apps Agreement remains active.
- IAP / subscription review screenshot is attached.
- IAP review notes explain purchase and restore path.
- First-time subscription submission is included with the app version submission if not previously approved.

Restore purchase path:

- Open `我的 / Me`.
- Open `Signal Path Pro` / paywall.
- Tap `恢复购买`.

Pro entitlement:

- Monthly or yearly Pro activates `premium_entitlement_active`.
- Active Pro unlocks Pro-gated areas and Pro quota display.
- Restore purchase rehydrates the same entitlement.

Free / Pro quota:

- Free quota allows core recording to continue even when AI quota is exceeded.
- Pro quota expands high-quality Today replies, light dialogue, Deep Weekly, Journey / Monthly Life Map, Misunderstanding Check, and deep model upgrades.
- Quota exceeded fallback must not block raw input saving.

Current status:

- IAP behavior was reported passed in TestFlight real-device testing by the user.
- App Store Connect subscription submission state was not independently verified through Fastlane precheck because IAP precheck is not supported with API key auth in this Fastlane flow.
- Do not mark the subscription-specific review state as independently verified until it is checked directly in App Store Connect.

## 5. App Review Notes

Suggested App Review Notes:

```text
Signal Path is not a diagnostic tool and does not score the user.

The app helps users record private life signals and turns them into small observations, Weekly observations, and a long-term Life Journey view.

If AI organization fails, the user's original text is still saved first. Users can continue recording even after AI quota is exceeded.

The Signal Library does not use user raw text. It only shows official, curated, abstract life patterns. Saving a library pattern creates a private observation for the user and does not create public interaction data.

Calendar and Health signals are currently used only as abstract auxiliary hints where applicable. Raw calendar event details and raw health samples are not uploaded, shown as detailed timelines, or used to generate public/shared patterns.

Signal Path Pro unlocks deeper Weekly observations, Life Journey review, Pro usage quota, and light dialogue around a saved signal.

Restore Purchase is available from the Me page by opening Signal Path Pro and tapping Restore Purchase.
```

Chinese internal note:

```text
Signal Path 不是诊断工具，也不是评分工具。
核心用途是帮助用户记录生活信号，并生成小观察、本周小观察和生活地图。
AI 整理失败时，用户原文仍会保存。
用户可以继续记录，即使超过 AI quota。
信号库不使用用户原文，只保存官方整理的生活模式。
日历和健康线索只作为抽象辅助，不直接上传明细。
Pro 解锁内容包括更深的本周小观察、生活地图、使用额度和轻量对话。
恢复购买入口位于「我的」页面。
```

## 6. Submission Flow Checklist

Target submission flow:

1. Open App Store Connect.
2. Select app `Signal Path`.
3. Select iOS version `3.0.0`.
4. Select build `3`.
5. Confirm all metadata fields are complete.
6. Confirm App Privacy and Age Rating are complete.
7. Confirm subscription products are ready and included for review if needed.
8. Confirm release option: release automatically after approval.
9. Add App Review Notes above.
10. Submit App Review.

Current submission status:

- App Review submission is complete through Fastlane.
- Submission time: `2026-06-03 08:56:11 JST`.
- Version submitted: `3.0.0`.
- Build submitted: `3`.
- Delivery / submission state: submitted for review.
- IAP submission status: App Review submission accepted; subscription-specific state should be monitored in App Store Connect because Fastlane API-key precheck cannot independently verify IAP review state.

Fastlane submission attempts:

1. First submit attempt selected build `3.0.0 (3)` and updated contents rights, but failed because release notes were missing.
2. Release notes were uploaded for `en-US`, `zh-Hans`, `zh-Hant`, and `ja`.
3. A later submit attempt selected build `3.0.0 (3)` and updated contents rights, but failed because required metadata fields were missing: `description`, `keywords`, and `supportUrl`.
4. Metadata fields were uploaded for all supported localizations.
5. Current Product Review screenshots were uploaded for all supported localizations.
6. Final submission was initially blocked because App Store Connect reported newly uploaded screenshots were still processing.
7. Retried submission after waiting several minutes; App Store Connect still returned the same screenshot-processing blocker.
8. After App Store Connect completed screenshot processing, final submission succeeded through Fastlane.

Successful submission record:

| Item | Value |
| --- | --- |
| Submission time | `2026-06-03 08:56:11 JST` |
| Version | `3.0.0` |
| Build | `3` |
| Release option | Automatic release after approval |
| App Review status | Submitted for Review |
| Fastlane confirmation | `Successfully submitted the app for review!` |
| IAP / subscription submission status | App Review submission accepted; subscription attachment / review state should be confirmed in App Store Connect because Fastlane API-key precheck cannot independently verify IAP state |

## 7. Verification Commands

Latest local validation before this readiness record:

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed |
| `flutter test` | Passed, 122 tests |
| `git diff --check` | Clean |

No code, UI, icon, Splash, LaunchImage, main color, or main background changes were made as part of ReleaseQA-2.10 readiness documentation.

## 8. Current ReleaseQA-2.10 Status

Readiness:

- TestFlight real-device QA: passed per user confirmation.
- Candidate version/build: `3.0.0 (3)`.
- Metadata: uploaded through Fastlane for all supported localizations.
- Product Review screenshots: uploaded through Fastlane from the 2.7H locked UI set and accepted after screenshot processing completed.
- IAP / subscription submission state: App Review submission accepted; subscription-specific review state should still be watched in App Store Connect.
- App Review submission: completed through Fastlane.

Next required action:

- Monitor App Store Connect review status for `3.0.0 (3)`.
- Confirm subscription review state in App Store Connect after the submission appears in review.
- Do not change build, UI, Purchase / Pro / quota, or privacy boundaries while review is pending unless Apple reports a review blocker.
