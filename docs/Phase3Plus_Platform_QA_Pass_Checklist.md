# Phase 3+ Platform QA Pass Checklist

Date: 2026-06-16

Purpose: close the platform-level release evidence gaps after engineering validation passed. This pass must not add new features or change the product scope.

## Status Model

| Track | Status | Meaning |
| --- | --- | --- |
| Engineering validation | Passed | Static analysis, unit/widget tests, backend tests, diff check, data/privacy tests are green |
| Platform QA | Open | Screenshots, IAP, Apple login, native permissions, and real-device safety checks are not fully verified |
| Production readiness | Blocked | Production submission must wait until Platform QA blockers are closed |

## Do Not Do In This Pass

- Do not add new features.
- Do not redesign UI.
- Do not change the data model unless a platform blocker proves it is required.
- Do not mark production ready based only on automated tests.

## Simulator Screenshot Recovery

Try once:

```bash
killall Simulator
killall CoreSimulatorService
xcrun simctl shutdown all
xcrun simctl erase all
sudo xcrun simctl delete unavailable
```

Then boot a fresh device and capture:

- Today
- Weekly
- Journey
- Signal Library
- Me
- ScheduleSignal / advanced signal settings
- Goal Practice / Life Experiment
- Paywall
- Backup / Delete account

If CoreSimulatorService or simdiskimaged fails again, stop using this Mac for screenshot sign-off and move to TestFlight / real-device evidence.

## TestFlight / Real Device Required Checks

### Launch And Navigation

- First launch.
- Onboarding.
- Today.
- Weekly.
- Journey.
- Signal Library.
- Me.
- Paywall.
- Backup / Delete account.

### IAP / Pro

- Monthly Pro purchase.
- Yearly Pro purchase.
- Restore purchase.
- Pro entitlement activation.
- Free quota display.
- Pro quota display.
- Quota exceeded while still allowing record save.
- Purchase failure fallback.

### Account / Backup

- Sign in with Apple.
- Create cloud backup snapshot.
- Restore backup on a clean install or second device.
- Delete account and all data.
- Confirm delete returns the app to new-user state.

### EventKit / HealthKit

- Calendar permission not requested.
- Calendar permission denied.
- Calendar permission granted.
- HealthKit permission not requested.
- HealthKit permission denied.
- HealthKit permission granted.
- Revoke permission in Settings and reopen app.
- Confirm no raw calendar titles, locations, attendees, notes, raw sleep samples, heart rate, workout details, or precise timelines are displayed or uploaded.

### Input / Layout

- Keyboard does not cover primary buttons.
- Bottom navigation does not cover content.
- Dynamic Island / status bar safe area is respected.
- Voice input path works.
- Text input path works.
- Schedule signal / title-only / time-only input works.
- Goal practice feedback works.

## Release Evidence Required

For each item, record pass/fail, device, build, and screenshot or screen recording path:

- Device model and iOS version.
- Build number.
- TestFlight install result.
- Screenshot or screen recording for each main page.
- IAP transaction result.
- Restore purchase result.
- Apple login result.
- Calendar permission result.
- HealthKit permission result.
- Backup restore result.
- Delete account result.

## Exit Criteria

Platform QA can close only when:

- Screenshots or recordings exist for all required user-facing flows.
- IAP monthly/yearly/restore works or blockers are explicitly fixed.
- Pro entitlement changes the app state correctly.
- Sign in with Apple works.
- Backup restore works.
- Delete account works and returns the app to new-user state.
- EventKit / HealthKit permission and fallback behavior is verified on device.
- No keyboard, safe-area, or bottom-nav blocker remains.

Production release remains blocked until all exit criteria pass.
