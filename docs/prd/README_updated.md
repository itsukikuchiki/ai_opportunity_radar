# PRD Index

This directory stores the product requirement and product design documents for **AI Observation Product / AI Opportunity Radar**.

The files document the product’s evolution from the early concept stage to the current Phase 2 planning stage.

---

## Document Map

## Current Active Documents

### `PRD_Phase2_v1.md`
The current **active product requirements document**.

Use this document to understand:
- the current Phase 2 scope
- free vs premium feature boundaries
- page-level changes for Today / Weekly / Journey
- delivery priorities for the next development stage

This is the **main execution document** for current product planning and implementation.

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

1. `PRD_Phase2_v1.md`
2. `Product_Design_Principles_v0.8.md`

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
- `Product_Design_Principles_v0.8.md`
- `../api_openapi_stub.yaml`

The active PRD explains **what the current product should be**.  
The design principles explain **how product decisions should be judged**.  
The OpenAPI stub explains **the current API surface used by the app / MVP flow**.

---

## Interpretation Rules

- `PRD_Phase2_v1.md` is the current execution PRD.
- `Product_Design_Principles_v0.8.md` remains the design judgement baseline.
- `PRD_v0.8_foundation.md` and `PRD_v0.9_FULL.md` should be treated as reference documents.
- Earlier PRDs should be treated as historical evolution records.
- When documents differ, prefer:
  1. `Product_Design_Principles_v0.8.md` for product philosophy and scope judgement
  2. `PRD_Phase2_v1.md` for current feature scope and implementation direction

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
