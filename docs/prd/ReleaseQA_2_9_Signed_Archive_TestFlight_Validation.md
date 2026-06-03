# ReleaseQA-2.9: Signed Archive And TestFlight Validation

Status: Archive, upload, internal TestFlight distribution, and user-confirmed real-device TestFlight validation succeeded.

Scope: verify the real iOS release chain after ReleaseQA-2.8 and the 2.7H visual lock. This stage does not add product features and does not change the visual baseline except for release-blocking fixes.

## 1. Visual Lock Boundary

ReleaseQA-2.7H Final Fix remains the only visual baseline.

No proactive changes were made to:

- primary color system
- primary background direction
- Splash layout
- LaunchScreen layout
- Phase 3 UI structure

One release-blocking asset fix was made:

- iOS AppIcon asset catalog PNGs were converted from RGBA to RGB because App Store Connect rejected transparent / alpha-channel large app icons.
- The separate transparent display asset used by Splash / onboarding remains transparent.
- This is a submission validation fix, not a visual redesign.

One release compliance fix was made:

- `ITSAppUsesNonExemptEncryption = false` was added to `ios/Runner/Info.plist`.
- The current uploaded build was also patched in App Store Connect with `usesNonExemptEncryption = false`.
- This resolved the TestFlight `MISSING_EXPORT_COMPLIANCE` blocker for internal testing.

## 2. Signing / Archive Configuration

| Item | Value |
| --- | --- |
| Bundle ID | `jp.sunrise.signalpath` |
| Development Team | `9S4L4FSR5Q` |
| Version | `3.0.0` |
| Build | `2` |
| Display Name | `Signal Path` |
| Deployment Target | `13.0` |
| Signing | Automatic signing with Team `9S4L4FSR5Q` |

Xcode workspace metadata was readable after running outside the sandbox.

## 3. Signed Archive / IPA

Command:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter build ipa --release
```

Final result:

- Signed archive succeeded.
- Archive output: `build/ios/archive/Runner.xcarchive`
- IPA output: `build/ios/ipa/SignalPath.ipa`
- IPA size: 25.6 MB.

## 4. Upload Attempt 1

Upload command:

```bash
xcrun altool --upload-app --type ios \
  -f build/ios/ipa/SignalPath.ipa \
  --apiKey M6GRG3Q27V \
  --apiIssuer a78135b4-5bf6-4508-bd2c-5ca140eddaa8
```

Result: failed.

Blocking error:

- `Invalid large app icon`
- The large app icon in the asset catalog contained transparency / alpha channel.

Fix applied:

- Converted all `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png` files to RGB.
- Converted `assets/icon-1024-noalpha.png` to RGB.
- Kept `assets/brand-icon-display.png` as RGBA because it is the separate Splash / onboarding display asset.

## 5. Upload Attempt 2

Rebuilt IPA after the AppIcon alpha fix.

Upload result: succeeded.

Delivery result:

- `UPLOAD SUCCEEDED with no errors`
- Delivery UUID: `00710e4e-ecaf-4d0c-aab9-e77064705264`
- Transferred: `25,363,428` bytes

This means App Store Connect accepted the uploaded IPA package. It does not yet prove TestFlight processing, installation, purchase, restore, entitlement, or quota behavior.

## 5B. TestFlight Internal Testing Distribution

App Store Connect API status check:

- Build ID: `00710e4e-ecaf-4d0c-aab9-e77064705264`
- Processing state: `VALID`
- Build audience type: `APP_STORE_ELIGIBLE`
- `usesNonExemptEncryption`: `false`
- Internal group: `Signal Path Internal Testers`
- Internal group ID: `da65b43f-8a52-4152-b1fb-1251d03e153f`

Initial attempt to add the build to the internal group failed:

- Error: `Build is not in an internally testable state`
- Cause: `buildBetaDetail.internalBuildState = MISSING_EXPORT_COMPLIANCE`

Fix:

- Patched current build export compliance to `usesNonExemptEncryption = false`.
- Added `ITSAppUsesNonExemptEncryption = false` to iOS `Info.plist` for future builds.

Final result:

- Build was added to `Signal Path Internal Testers`.
- `internalBuildState = IN_BETA_TESTING`
- `externalBuildState = READY_FOR_BETA_SUBMISSION`

This means TestFlight internal distribution is ready. It does not yet prove real-device installation or IAP behavior.

## 6. Completed In This Stage

| Item | Status |
| --- | --- |
| Signed Archive | Passed |
| App Store IPA export | Passed |
| AppIcon alpha validation blocker | Fixed |
| IPA upload to App Store Connect | Passed |
| Delivery UUID recorded | Passed |
| Export compliance blocker | Fixed |
| Added to internal TestFlight group | Passed |

## 7. Pending Real-Device / TestFlight Validation

The build has processed and internal TestFlight distribution is available. Do not mark the following complete until build `3.0.0 (2)` is installed on a real device and verified:

- TestFlight installation on real device
- first launch
- onboarding
- Today page
- Weekly page
- Journey page
- Signal Library page
- Me page
- monthly Pro purchase
- yearly Pro purchase
- restore purchase
- Pro entitlement activation
- free quota display
- Pro quota display
- quota exceeded fallback
- recording still works after quota exceeded
- AI failure preserves raw input
- Day 0 / Day 1 / 7 active app days Weekly / Journey states

## 8. Non-Blocking Advisories

- Flutter still reports Swift Package plugins while the project retains CocoaPods integration. This did not block archive, IPA export, or upload.
- Flutter reports upcoming UIScene lifecycle requirements for future iOS versions. This did not block archive, IPA export, or upload.

## 9. Current ReleaseQA-2.9 Status

ReleaseQA-2.9 is complete for the uploaded TestFlight validation stage.

- Archive and upload path: complete.
- Internal TestFlight distribution: complete.
- Real-device TestFlight validation: complete per user confirmation.
- IAP / restore / entitlement / quota QA: complete per user confirmation.

Final real-device QA summary supplied by the user before ReleaseQA-2.10:

| Scenario | Result |
| --- | --- |
| TestFlight installation | Passed |
| First launch | Passed |
| Onboarding 3 pages | Passed |
| Today save | Passed |
| Weekly / Journey Day 0 state | Passed |
| Weekly / Journey Day 1 state | Passed |
| Weekly 7 active app days state | Passed |
| AI failure preserves raw input | Passed |
| Quota exceeded still allows recording | Passed |
| Monthly Pro purchase | Passed |
| Yearly Pro purchase | Passed |
| Restore purchase | Passed |
| Pro entitlement activation | Passed |
| Free / Pro quota display | Passed |

Blockers:

- None reported by user after TestFlight real-device validation.

Non-blockers:

- Flutter / iOS Swift Package + CocoaPods advisory remains non-blocking.

Deferrable:

- Real EventKit permission integration and real HealthKit permission integration remain future advanced enhancements. The current release uses internal SignalCard evidence and abstract hint boundaries.

Next stage:

- ReleaseQA-2.10 App Store Review Submission Readiness for candidate `3.0.0 (3)`.
