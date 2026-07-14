# Phase 4 Automated Test Matrix

Status: active guardrail
Target: Signal Path 4.0.0+
Purpose: prevent obvious UI, data-chain, and interaction regressions before TestFlight.

Last reconciled: 2026-07-13 against the current `docs/active/` product design.

Reconciled local baseline on that date: Flutter `359 / 359` passed with
`68.3%` full-suite line coverage (`77.5%` for `test/core`), backend
`70 / 70` passed, Flutter analyzer clean, and every Flutter/backend test file
assigned to a CI gate. Test counts and line coverage are audit evidence, not a
substitute for the product-contract and platform boundaries below.

Status language in this document:

- **Automated**: a repository test currently asserts the behavior.
- **Partial**: part of the behavior is asserted, but a required branch remains open.
- **Target / Pending**: approved behavior that is not yet fully implemented or
  does not yet have release-blocking automation. It must not be reported as
  shipped or passed.

## Why Previous Automation Missed Visible Bugs

The previous suite was healthy for repository logic and some widget smoke tests, but it did not fail on several release-visible problems:

- UI tests did not cover compact phones, large phones, and tablet widths as a matrix.
- RenderFlex overflow and off-screen hit targets were not treated as release blockers.
- Critical buttons were often checked as text presence, not tapped as real controls.
- Bottom navigation and floating controls were not checked for obstruction.
- Signal Library filters were visually present but not verified as state-changing actions.
- Secondary pages were not checked for safe-area back controls.
- Native platform flows cannot be fully closed by mocks, but their mock/provider paths were not separated clearly from real-device QA.

## Required Automated Layers

| Layer | Coverage | Examples | Required before build |
| --- | --- | --- | --- |
| Unit / model | Pure data rules | eligibility, quotas, language mapping, privacy flags | Yes |
| Repository / service | persistence and failure behavior | save-first, retry, idempotency, delete account | Yes |
| View model | screen state from data | inclusion, filtering, fallback, local-first state | Yes |
| Widget page | visible behavior | buttons, chips, empty/filled states, localization | Yes |
| Release UI guardrail | multi-viewport layout and hit testing | overflow, safe area, bottom nav, tappable controls | Yes |
| Main tab visual density | Today / Weekly / Life Experiment / Journey / Me | 18/14 page padding, safe area + 96 bottom clearance, 34–36 hero title, 16–17 section title, compact-card sizing, narrow-screen overflow | Yes |
| Platform mock | fake native providers | HealthKit denied, unavailable, authorized abstract hints; Calendar compatibility remains outside the current user surface | Yes |
| TestFlight / real device | native platform proof | IAP, HealthKit, keyboard, screenshots | Required for Platform QA, not replaceable by automation |

## Viewport Matrix

Release UI guardrail tests must run the primary pages at:

- Compact phone: `320 x 640`
- Regular phone: `390 x 844`
- Large phone: `430 x 932`
- Tablet: `768 x 1024`

Failure conditions:

- Any Flutter render exception.
- Any RenderFlex overflow.
- Required section title outside the viewport when first rendered.
- Critical tab label or action cannot be tapped.
- Back button is outside the safe area.
- Bottom navigation obscures primary interactive content.

## Page / Section Matrix

### Onboarding

| Page | Current purpose | Automated expectations | Coverage status |
| --- | --- | --- | --- |
| 1. Record life signals | Explain text, voice, state, Signal Library reference, and AI judgement as entry sources | the first Flutter frame is the opening scene; enlarged Signal Path icon is used as background art; skip remains reachable. The native-to-Flutter no-white-transition claim remains physical-device QA. | Automated for Flutter layout; **Platform QA Pending** for native transition |
| 2. Weekly + Life Experiment | Explain Weekly review and the separate Life Experiment area without inventing a one-card-only flow | Weekly and Life Experiment previews are both visible; icon background replaces the old decorative circle; copy matches the current page roles | Automated |
| 3. Journey + Pro depth | Explain long-term Journey aggregation and paid deep reports | Journey and Pro preview is visible; free overview and paid depth are not conflated; icon background follows the same visual system | Automated for layout and implemented evidence surface; independent versioned 28-day interpretive generator remains Target / Pending |
| 4. Focus domains | Select the life areas AI should prioritize | multi-select focus domains persist when Start is tapped, reappear in Me, and can be changed later; button copy is “Start”, not “Start setup” | Automated locally; remote multi-device focus sync is Target / Pending |

### Today

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Dynamic Today hero | local date + confirmed same-day SignalCards | compact hero merges the useful “Today can be viewed this way” summary; empty state is neutral and does not claim low energy, insufficient recovery, or another negative condition; no fixed fake overview |
| Quick record | local draft + SignalCard create path | text entry saves first; voice/state/library buttons are visible and tappable; Schedule is absent as a peer input; no standalone prediction button |
| Voice / state sheets | draft input only until save | “Skip for now” closes without a write; state note says “补一句” (“Add a sentence”); no standalone Observation record is created |
| AI predicted signal | Observation + confirmed SignalCard | generates automatically from eligible context; accurate/somewhat can be edited before optional timeline insertion; inaccurate is dismissed |
| Diary timeline | SignalCard + MicroAction + LifeExperiment projection | compact density matches Today; only Signal, Small Action, and Small Experiment filters appear; no Schedule peer entry |
| Three-signal gate | eligible confirmed SignalCards | before three valid same-day signals, Small Action says content starts after three signals; before three valid same-week signals, experiment candidates remain forming in Weekly rather than appearing in Today |
| Adopted action / experiment | adopted MicroAction + active LifeExperiment + daily feedback | Today shows only adopted items and real date-deduplicated `X/7` progress; the next-week candidate/forming card is absent |
| Local sync notice | local queue state | retry action is tappable; failure does not delete content or create duplicate timeline items |
| Bottom spacing | shell navigation inset | final content clears the floating navigation without an oversized trailing blank area |

Coverage status:

- Dynamic hero, skip behavior, prediction confirmation, compact timeline, and
  removal of the Today next-week card: **Automated**.
- Today and Weekly three-signal gates, plural candidate groups, independent
  zero-to-many adoption, the Today `3 + 3` projection cap, and real
  object-local `X/7` progress: **Automated**.

### Weekly

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Weekly hero + AI read | eligible SignalCards + Weekly insight | compact date range and AI quote fit the Today-based density; empty/fallback copy does not claim certainty |
| Signal distribution | weekly SignalCard aggregation | donut and rows use only eligible signals and fit one column below 600px |
| Behavior pattern | Weekly pattern generator | the current behavior path is readable as steps; labels and arrows do not overflow |
| Energy Budget | internal signals + abstract hints | summary visualization and legend fit the viewport; hints cannot override confirmed signals |
| Small actions and review | adopted MicroActions + feedback | helpful, difficult, and next-adjustment evidence remain separate from experiment progress |
| Current experiment result | active LifeExperiment + date-deduplicated feedback | result and review use actual feedback days; MicroAction tries cannot substitute for experiment progress |
| Next-week experiment | ExperimentCandidate group | forming state and candidate-list entry live in Weekly rather than Today; feedback cannot implicitly adopt an experiment; candidate list is gated by three valid weekly signals |
| Inclusion notes | SignalCard eligibility | inaccurate, sync failed, excluded do not enter analysis |

Plural experiment candidates, zero-to-many adoption, per-item progress,
Energy Budget influence, and the Weekly-only candidate entry are
**Automated**. Only old embedded snapshot fallbacks are Compatibility.

### Journey

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Journey hero | focus domains + Journey snapshot | shows the long-term direction in the shared main-tab density; fallback does not claim certainty |
| Track overview | visible Journey traces | record days, important moments, review notes, and related experiments are derived values rather than fixed demo numbers |
| Observations | confirmed SignalCards + derived trace evidence | only user-visible evidence is shown; internal Observation/trace payloads do not become peer records |
| Monthly fragments | Journey traces grouped by month | fragments remain readable on compact screens and preserve source dates |
| Monthly calendar | dated Journey traces | date cells reflect real evidence and do not fabricate activity |
| Life curve | monthly trace aggregation | curve points are backed by evidence and render without clipping |
| Gentle review | SignalCards + LifeExperiment feedback + Journey snapshot | review treats skipped/not-helpful/adjusted as learning and never blocks Today/Weekly |
| Pro deep report | versioned reflection result | free Journey remains useful; paid depth has an explicit entry and stable report boundary |

The overview sections, readiness states, free evidence layer, Pro gate,
dedicated Journey Pro route, bounded evidence, factual comparison, and
SignalCard follow-up are **Automated**. The independent versioned 28-day
interpretive generator remains **Target / Pending** and is not represented as
an existing report.

### Signal Library

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Category chips | curated pattern metadata | chips filter real card list and remain tappable on compact screens |
| Shared signal cards | official curated patterns | no user raw text or user story appears |
| Accurate / Somewhat / Not accurate | optional `library_saved` SignalCard only | first two open editable timeline confirmation; inaccurate and Do not add are zero-write |
| Timeline insertion | curated reference + optional user edit | creates one idempotent private SignalCard with no Observation, MicroAction, or LifeExperiment payload |

### Me

| Section | Data source | Automated expectations |
| --- | --- | --- |
| Usage preferences | local preferences | navigation rows remain tappable |
| Pro / quota | entitlement + usage counters | quota visible and updates from entitlement state |
| Restore Purchase (Pro sheet) | StoreKit current entitlements + delayed purchase stream | automated paths cover native entitlement, fallback, delay, persistence, and actionable empty/error states; real-device status remains **Blocker reopened / Pending** |
| Advanced signal settings | HealthKit provider state | denied/unavailable/authorized states have fallback and back button inside safe area; Calendar has no current user entry |
| Delete account | local DB + account deletion endpoint | canonical data/control-plane rows, local profile media, session/account state, focus preferences, external hint cache, and onboarding state are cleared; StoreKit entitlement remains an independent control plane |

User-facing Apple backup/upload/restore entry points are retired from the active
product and therefore are not active UI test targets. This does not remove the
separate StoreKit **Restore Purchase** requirement.

### Candidate Selection And Progress Pages

| Surface | Current contract | Coverage status |
| --- | --- | --- |
| Small Action candidates | after three eligible same-day signals, show up to three generated actions on a dedicated page; allow zero-to-many adoption | Automated |
| Small Experiment candidates | after three eligible same-week signals, open a dedicated candidate page from Weekly; do not route to the Life Experiment archive | Automated |
| Adoption state | each candidate has an independent adopted/rejected state and creates at most one canonical item | Automated |
| Seven-day grid | each adopted item accepts date-deduplicated daily feedback; the last valid event per local date wins and exposes real `X/7` progress | Automated |
| Today projection | only adopted items and their actual progress appear on Today, with at most three of each type | Automated |

## Secondary Pages

Automated tests should cover at least smoke/hit/safe-area checks for:

- Diary / account book.
- Signal detail / light dialogue.
- Voice transcription sheet.
- Small Action candidate selection and progress.
- Small Experiment candidate selection and progress.
- Paywall and restore purchase UI.
- Advanced signal settings.
- Delete account confirmation.

## Privacy Guardrails

Automation must keep these assertions active:

- `SignalCard.raw_text` never enters Signal Library.
- `library_saved` is private and unconfirmed by default.
- User corrections and “Your context” do not enter shared content.
- Calendar raw fields are not displayed or downstreamed.
- Health raw samples are not displayed or downstreamed.
- Abstract external hints cannot override user-confirmed SignalCards.
- `included_in_summary`, `included_in_weekly`, and `included_in_journey` do not mean confirmed or high-confidence evidence.

## Commands

Frontend:

```bash
cd /Users/yangyang/ai_opportunity_radar/frontend_flutter
flutter analyze
flutter test --no-pub
flutter test --no-pub test/features/release_qa/release_ui_guardrails_test.dart
cd ..
bash scripts/check_ci_test_manifest.sh
git diff --check
```

Backend:

```bash
cd /Users/yangyang/ai_opportunity_radar/backend
python3 -m pytest
```

## Platform QA Boundary

Automation and simulator mocks do not close these items:

- Monthly and yearly IAP purchase sheets.
- Restore Purchase with active and inactive subscription states.
- Restore fallback when StoreKit 2 is unavailable or App Store sync fails.
- Delayed restored transactions keep the UI in the restoring state until the
  purchase stream resolves.
- Pro entitlement propagation from StoreKit, including receipt persistence.
- Treat Xcode StoreKit, TestFlight Sandbox, and App Store Production as three
  isolated purchase environments. A Production subscription is validated with
  the App Store build, never by expecting it to appear in TestFlight.
- HealthKit native permission prompt and Settings revocation.
- Real keyboard, Dynamic Island, bottom safe area, and physical-device screenshot evidence.

These must remain `Platform QA: Open` until TestFlight or real-device evidence is collected.

## Exit Criteria

Engineering validation can be marked `Passed` only when:

- Frontend analyze passes.
- Full Flutter test suite passes.
- Release UI guardrail matrix passes.
- Backend pytest passes.
- `git diff --check` is clean.
- The test matrix document is updated for any new screen, feature, or native provider.

Production readiness can be marked `Release Candidate` only when Platform QA evidence is also complete.
