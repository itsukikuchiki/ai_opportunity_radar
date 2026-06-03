# PRD Index

This directory stores the product requirement and product design documents for **AI Observation Product / AI Opportunity Radar**.

The files document the product’s evolution from the early concept stage to the current Phase 3 planning stage.

---

## Document Map

## Current Active Documents

### `PRD_Phase3_Technical_Design_v1.md`
The current **active technical design document** for Phase 3.

Use this document to understand:
- Signal Card schema and migration requirements
- Today V3A / V3B implementation order
- AI parser fallback and save-first behavior
- Free / Pro quota and usage logging requirements
- Energy Budget, Misunderstanding Check, and Signal Library roadmap constraints
- acceptance tests before large UI changes

This is the **main execution document** for the next implementation stage.

---

### `Phase3_V3B4_Today_Closeout_Release_QA.md`
The current **Today V3B closeout and Release QA checklist**.

Use this document to understand:
- V3B-1 / V3B-2 / V3B-3 engineering acceptance status
- the remaining Release QA blocker for manual UI screenshots / recordings
- Today V3B data chain from input to SignalCard, Summary, and inclusion marking
- inclusion field ownership and future Weekly / Journey handoff points

This is the best single entry point for reviewing the completed Today V3B work.

---

### `PRD_Phase2_v1.md`
The current **Phase 2 product requirements reference**.

Use this document to understand:
- the current Phase 2 scope
- free vs premium feature boundaries
- page-level changes for Today / Weekly / Journey
- delivery priorities for the next development stage

This remains the reference for the completed Phase 2 scope and premium feature boundaries.

---

### `Product_Design_Principles_v0.8.md`
The current design-principles document.

Use this document to understand:
- the product’s design philosophy
- why the product is observation-first
- why it uses a private diary / notebook-like form
- how AI acknowledgement should behave
- how future features should be evaluated against the core product identity

This document remains the main reference for product judgement and scope control.

---

## Foundation / Reference Documents

### `PRD_v0.8_foundation.md`
The v0.8 product foundation.

Use this document to understand:
- the original product scope
- page roles
- feature boundaries
- expansion constraints
- the base product model before Phase 2 extension

This is still an important reference document, but it is **not the main execution PRD anymore**.

---

### `PRD_v0.9_FULL.md`
The v0.9 full product structure document.

Use this document to understand:
- the page-level structure established after v0.8
- the core loop and module composition
- earlier full-structure product thinking before Phase 2 refinement

This document should be treated as a **historical / structural reference**, not the current execution source of truth.

---

## Historical PRD Evolution

- `PRD_v0.1.md`  
  Initial product framing, core problem, and MVP direction.

- `PRD_v0.2.md`  
  Expanded information architecture and page-level product structure.

- `PRD_v0.3.md`  
  Further clarified page responsibilities, user flow, and functional decomposition.

- `PRD_v0.4.md`  
  Moved into API / schema / interaction-flow oriented product specification.

- `PRD_v0.5.md`  
  Engineering kickoff package with implementation-oriented structure.

- `PRD_v0.6.md`  
  Continued refinement of engineering and product alignment.

- `PRD_v0.7.md`  
  First runnable implementation package and local demo-oriented PRD handoff.

---

## How to Use These Documents

### If you want the current product definition
Start with:

1. `PRD_Phase3_Technical_Design_v1.md`
2. `PRD_Phase2_v1.md`
3. `Product_Design_Principles_v0.8.md`

---

### If you want the product foundation before Phase 2
Read:

1. `PRD_v0.8_foundation.md`
2. `PRD_v0.9_FULL.md`

---

### If you want the historical evolution
Read in order:

1. `PRD_v0.1.md`
2. `PRD_v0.2.md`
3. `PRD_v0.3.md`
4. `PRD_v0.4.md`
5. `PRD_v0.5.md`
6. `PRD_v0.6.md`
7. `PRD_v0.7.md`
8. `PRD_v0.8_foundation.md`
9. `PRD_v0.9_FULL.md`
10. `PRD_Phase2_v1.md`

---

### If you are working on implementation
Use together:

- `PRD_Phase2_v1.md`
- `PRD_Phase3_Technical_Design_v1.md`
- `Phase3_V3B4_Today_Closeout_Release_QA.md`
- `Phase3_V3C1_Weekly_SignalCard_Inclusion.md`
- `Phase3_V3C2_Weekly_Low_Pressure_Output.md`
- `Phase3_V3C3_Weekly_Life_Experiment_Minimal_Loop.md`
- `Phase3_V3C4_Weekly_Closeout_Journey_Entry.md`
- `Phase3_V3D1_Journey_SignalCard_Experiment_Foundation.md`
- `Phase3_V3D2_Journey_Review_Adjust_Output.md`
- `Phase3_V3D3_Journey_Closeout_Phase3_Main_Chain.md`
- `Phase3_V3E1_Energy_Budget_Basic_Internal_Signals.md`
- `Phase3_V3E2_Energy_Budget_Low_Pressure_UX.md`
- `Phase3_V3E3_Energy_Budget_Closeout_Signal_Library_Entry.md`
- `Phase3_V3F1_Signal_Library_Privacy_Safe_Foundation.md`
- `Phase3_V3F1A_Signal_Library_Privacy_Evidence.md`
- `Phase3_V3F2_Library_Saved_SignalCard_Integration.md`
- `Phase3_V3F3_Signal_Library_Closeout_Phase3_Boundary.md`
- `Phase3_V3G1_Calendar_HealthKit_Consent_Boundary.md`
- `Phase3_V3G2_Calendar_Schedule_Density_Local_Prototype.md`
- `Phase3_V3G3_HealthKit_Recovery_Signal_Local_Prototype.md`
- `Phase3_V3G4_Advanced_Energy_Budget_Abstract_Hint_Integration.md`
- `Phase3_V3G5_Advanced_Energy_Budget_Closeout_Phase3_Prep.md`
- `Phase3_Closeout_1_Full_Implementation_Closeout_Release_QA_Plan.md`
- `ReleaseQA_2_7B_Brand_Color_Typography_Illustration_Refinement.md`
- `ReleaseQA_2_7C_Visual_Language_Finalization.md`
- `ReleaseQA_2_7D_UI_Freeze_Fix.md`
- `ReleaseQA_2_7E_Final_Visual_Polish.md`
- `ReleaseQA_2_7F_Brand_Language_Onboarding_Final_Adjustments.md`
- `ReleaseQA_2_7H_Visual_Direction_Lock.md`
- `ReleaseQA_2_8_Functional_Stability_PreRelease.md`
- `ReleaseQA_2_9_Signed_Archive_TestFlight_Validation.md`
- `Product_Design_Principles_v0.8.md`
- `../api_openapi_stub.yaml`

The Phase 3 technical design explains **what should be implemented next and in what order**.
The Phase 2 PRD explains **the current shipped product baseline**.
The design principles explain **how product decisions should be judged**.
The OpenAPI stub explains **the current API surface used by the app / MVP flow**.

---

## Interpretation Rules

- `PRD_Phase3_Technical_Design_v1.md` is the current execution design for V3A / V3B.
- `Phase3_V3B4_Today_Closeout_Release_QA.md` is the current V3B closeout / QA source of truth.
- `Phase3_V3C1_Weekly_SignalCard_Inclusion.md` is the current Weekly SignalCard inclusion source of truth.
- `Phase3_V3C2_Weekly_Low_Pressure_Output.md` is the current Weekly low-pressure output source of truth.
- `Phase3_V3C3_Weekly_Life_Experiment_Minimal_Loop.md` is the current Weekly Life Experiment source of truth.
- `Phase3_V3C4_Weekly_Closeout_Journey_Entry.md` is the V3C closeout and V3D Journey entry source of truth.
- `Phase3_V3D1_Journey_SignalCard_Experiment_Foundation.md` is the current Journey SignalCard and Experiment History foundation source of truth.
- `Phase3_V3D2_Journey_Review_Adjust_Output.md` is the current Journey low-pressure Review & Adjust output source of truth.
- `Phase3_V3D3_Journey_Closeout_Phase3_Main_Chain.md` is the current V3D closeout and Phase 3 main-chain summary source of truth.
- `Phase3_V3E1_Energy_Budget_Basic_Internal_Signals.md` is the current Energy Budget internal-signal foundation source of truth.
- `Phase3_V3E2_Energy_Budget_Low_Pressure_UX.md` is the current Energy Budget low-pressure Weekly UX source of truth.
- `Phase3_V3E3_Energy_Budget_Closeout_Signal_Library_Entry.md` is the current V3E closeout and V3F Signal Library entry source of truth.
- `Phase3_V3F1_Signal_Library_Privacy_Safe_Foundation.md` is the current Signal Library privacy-safe foundation source of truth.
- `Phase3_V3F1A_Signal_Library_Privacy_Evidence.md` is the current Signal Library privacy test and evidence source of truth.
- `Phase3_V3F2_Library_Saved_SignalCard_Integration.md` is the current Library-saved SignalCard integration source of truth.
- `Phase3_V3F3_Signal_Library_Closeout_Phase3_Boundary.md` is the current V3F closeout and Phase 3 implementation boundary source of truth.
- `Phase3_V3G1_Calendar_HealthKit_Consent_Boundary.md` is the current Advanced Energy Budget Calendar / HealthKit consent and privacy boundary source of truth.
- `Phase3_V3G2_Calendar_Schedule_Density_Local_Prototype.md` is the current Calendar schedule-density local prototype source of truth.
- `Phase3_V3G3_HealthKit_Recovery_Signal_Local_Prototype.md` is the current HealthKit recovery-signal local prototype source of truth.
- `Phase3_V3G4_Advanced_Energy_Budget_Abstract_Hint_Integration.md` is the current Advanced Energy Budget abstract hint integration source of truth.
- `Phase3_V3G5_Advanced_Energy_Budget_Closeout_Phase3_Prep.md` is the current V3G closeout and Phase 3 implementation closeout prep source of truth.
- `Phase3_Closeout_1_Full_Implementation_Closeout_Release_QA_Plan.md` is the current Phase 3 full implementation closeout and Release QA plan source of truth.
- `ReleaseQA_1_iOS_Toolchain_UI_Evidence.md` is the current iOS toolchain repair and Phase 3 simulator UI evidence source of truth.
- `ReleaseQA_2_Archive_TestFlight_Purchase_QA.md` is the current archive, TestFlight upload, and purchase QA boundary source of truth.
- `ReleaseQA_2_5_Phase3_Productization_Expansion.md` is the current Phase 3 productization implementation boundary source of truth.
- `ReleaseQA_2_7D_UI_Freeze_Fix.md` is the current visual freeze fix source of truth before QA3.
- `ReleaseQA_2_7E_Final_Visual_Polish.md` is the current final launch / brand / illustration polish source of truth before TestFlight refresh.
- `ReleaseQA_2_7F_Brand_Language_Onboarding_Final_Adjustments.md` records the internal timing and multilingual terminology baseline.
- `ReleaseQA_2_7G_Product_UI_Finalization.md` is the current product-facing UI, launch/onboarding, and Product Review screenshot source of truth before QA3.
- `ReleaseQA_2_7H_Visual_Direction_Lock.md` is the current locked visual direction source of truth: white / near-white, pale blue-gray, deep blue, and original Signal Path icon language.
- `ReleaseQA_2_8_Functional_Stability_PreRelease.md` is the current functional chain and pre-release stability check source of truth after visual lock.
- `ReleaseQA_2_9_Signed_Archive_TestFlight_Validation.md` is the current signed archive, IPA upload, and pending real-device TestFlight validation source of truth.
- `ReleaseQA_2_6_Regression_TestFlight_Refresh.md` is the current regression build, data-state screenshot evidence, and TestFlight refresh source of truth.
- `ReleaseQA_2_7_UI_Visual_Redesign.md` is the current Phase 3 visual redesign evidence source of truth.
- `ReleaseQA_2_7A_Visual_Refinement_Pass.md` is the current Phase 3 visual refinement and product-review screenshot source of truth.
- `ReleaseQA_2_7B_Brand_Color_Typography_Illustration_Refinement.md` is the current Phase 3 brand, color, typography, illustration, and product-like app-frame refinement source of truth.
- `ReleaseQA_2_7C_Visual_Language_Finalization.md` is the current visual language finalization source of truth before TestFlight refresh and QA3.
- `PRD_Phase2_v1.md` is the Phase 2 reference baseline.
- `Product_Design_Principles_v0.8.md` remains the design judgement baseline.
- `PRD_v0.8_foundation.md` and `PRD_v0.9_FULL.md` should be treated as reference documents.
- Earlier PRDs should be treated as historical evolution records.
- When documents differ, prefer:
  1. `Product_Design_Principles_v0.8.md` for product philosophy and scope judgement
  2. `PRD_Phase3_Technical_Design_v1.md` for Phase 3 implementation direction
  3. `PRD_Phase2_v1.md` for shipped Phase 2 behavior and constraints

---

## Current Product Summary

At the current stage, the product is defined as:

- a private diary / notebook-like observation product
- focused on low-friction real-fragment capture
- centered on observation before management
- supported by light AI acknowledgement and follow-up
- structured around Today / Weekly / Journey / Me
- extended in Phase 2 with clearer free vs premium boundaries
- aimed at helping users gain structured personal understanding over time

Phase 2 focuses on:
- strengthening the base experience
- improving Today / Weekly / Journey reliability
- introducing premium depth without breaking the observation-first model

Future additions must still remain lightweight and subordinate to the core observation-and-judgement flow.
