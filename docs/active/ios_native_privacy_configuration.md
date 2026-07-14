# iOS Native Schemes And Privacy Configuration

Last updated: 2026-07-14

Status: **current native configuration contract for device QA and release**.

This document fixes the boundary between local Xcode fixtures, real StoreKit
channels, native permission behavior, and the privacy statements shown by iOS.
It does not create new product functionality.

## 1. StoreKit Scheme Contract

| Shared scheme | Configuration | Contract |
| --- | --- | --- |
| `Runner` | No `StoreKitConfigurationFileReference` | Default normal environment. Use for physical-device QA, App Store Connect/Sandbox testing, archive, TestFlight, and release. |
| `Runner-LocalStoreKit` | Launch action references `../SignalPath.storekit` | Local Xcode purchase and restore simulation only. |

Rules:

1. `Runner` is the normal scheme. It must never silently inherit the local
   StoreKit file.
2. `Runner-LocalStoreKit` must be selected explicitly and must not be used to
   claim TestFlight Sandbox or App Store Production acceptance.
3. TestFlight archives use `Runner`. TestFlight obtains StoreKit behavior from
   its Sandbox channel; it does not use the local Xcode configuration.
4. `SignalPath.storekit` stays a project-side test fixture, not a copied app
   resource.
5. The local products use the real SignalPath monthly/yearly product IDs, but
   local transactions remain isolated from TestFlight and Production.

The local product descriptions use the final Pro range:

- This Week Deep Read;
- Journey L3 evidence and period comparison;
- follow-up grounded in a selected real SignalCard;
- structured self-review;
- L1 Attune short dialogue and expanded AI quota.

They must not advertise response-style switching, ownership of the user's Free
facts, Calendar access, raw Health access, or the future independent 28-day
interpretive generator as a shipped entitlement.

## 2. Permission Localization

iOS purpose strings are provided through localized `InfoPlist.strings` in four
languages:

| Language | Folder |
| --- | --- |
| English | `Runner/en.lproj` |
| Simplified Chinese | `Runner/zh-Hans.lproj` |
| Traditional Chinese | `Runner/zh-Hant.lproj` |
| Japanese | `Runner/ja.lproj` |

The localized keys cover:

- `NSSpeechRecognitionUsageDescription`;
- `NSMicrophoneUsageDescription`;
- `NSPhotoLibraryUsageDescription`;
- `NSHealthShareUsageDescription`;
- `NSHealthUpdateUsageDescription`;
- retained `NSCalendarsUsageDescription` and
  `NSCalendarsFullAccessUsageDescription` for the compiled future bridge.

English values remain in `Info.plist` as the development/fallback language.
Copy in every language must describe the same data use; localization must not
weaken the privacy boundary.

## 3. Speech And Microphone

Voice input is device-only:

1. native code chooses only an `SFSpeechRecognizer` with
   `supportsOnDeviceRecognition`;
2. every recognition request sets `requiresOnDeviceRecognition = true`;
3. audio is processed only while recognition is active and is not saved or
   uploaded;
4. if on-device recognition is unavailable for the chosen language/device, the
   app reports that condition and leaves manual text input available;
5. the app must not silently fall back to Apple's network recognizer.

Device QA verifies both a supported locale and the unavailable path. The latter
must not produce a network-recognition permission or save a partial SignalCard.

## 4. HealthKit Read-Only Boundary

HealthKit is optional and read-only. The current allowlist reads sleep, steps,
and workout data only to derive abstract recovery context for Energy Budget.
Raw samples are not uploaded, shown as a raw timeline, written to Signal
Library, or used as an independent SignalCard.

Native authorization passes `toShare: nil`; there is no HealthKit write path.
`NSHealthUpdateUsageDescription` is retained because the signed capability and
submission tooling previously required the key. Its copy must explicitly say
that Signal Path does **not** add or modify Health data. Keeping that key is not
permission to introduce a write type. Any future Health write requires a new
product decision, code review, privacy review, and QA plan.

## 5. Calendar / EventKit Boundary

Calendar remains a future Target only:

- no current user-facing Calendar setting or onboarding entry;
- no Calendar data in current Energy Budget, candidate context, source hash,
  Weekly, Journey, or Pro evidence;
- no EventKit authorization request from the current runtime;
- the retained bridge may return abstract busy blocks only if the device was
  already authorized, and it does not retain titles, locations, attendees, or
  notes;
- Calendar/EventKit is excluded from this QA round.

The Calendar purpose keys remain localized because the future bridge is still
compiled. They do not authorize showing a prompt. If a Calendar permission
sheet appears during current QA, treat it as a regression and fail the pass.

## 6. Sign In With Apple

The current app has no Sign in with Apple entry or account contract and must not
ship an unused Sign in with Apple plugin or entitlement. Removing that unused
dependency does not change StoreKit ownership: purchases remain managed by
Apple, while diary/content restoration is not promised across devices until a
real SignalPath account model exists.

## 7. Native QA Gate

Before TestFlight:

1. validate both shared scheme XML files and their StoreKit-reference split;
2. archive with `Runner`, never `Runner-LocalStoreKit`;
3. inspect the built app and confirm local `SignalPath.storekit` is not bundled;
4. switch device language through English, Simplified Chinese, Traditional
   Chinese, and Japanese and capture each applicable permission prompt;
5. verify speech succeeds only with on-device recognition and degrades to text
   when unavailable;
6. verify Health authorization requests read types only and produces abstract
   hints;
7. verify no Calendar permission sheet appears;
8. verify the signed entitlements contain HealthKit as intended and no unused
   Sign in with Apple entitlement.

Purchase-channel acceptance remains defined in
[Pro purchase and entitlement](purchase_entitlement.md), and build/API profiles
remain defined in [Device build matrix](device_build_matrix.md).
