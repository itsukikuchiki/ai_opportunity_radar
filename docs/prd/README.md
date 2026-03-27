# PRD Index

This directory stores the product requirement and product design documents for **AI Opportunity Radar**.

The files are organized in chronological order so the evolution of the product can be traced clearly from early concept to current foundation.

---

## Document Map

### Historical PRD evolution

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

## Current foundation documents

### `PRD_v0.8_foundation.md`
The current v0.8 product foundation.

Use this document to understand:
- current product scope
- page roles
- feature boundaries
- expansion constraints
- what is and is not part of the v0.8 product model

This is the best starting point for current product planning.

---

### `Product_Design_Principles_v0.8.md`
The current design-principles document.

Use this document to understand:
- the product’s design philosophy
- why the product is observation-first
- why it uses a private diary / notebook-like form
- how AI acknowledgement should behave
- how future features should be evaluated against the core product identity

This document is the main reference for product judgement and scope control.

---

## How to Use These Documents

### If you want the current product definition
Start with:

1. `PRD_v0.8_foundation.md`
2. `Product_Design_Principles_v0.8.md`

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

---

### If you are working on implementation
Use together:

- `PRD_v0.8_foundation.md`
- `Product_Design_Principles_v0.8.md`
- `../api_openapi_stub.yaml`

The PRD foundation explains **what the product should be**.  
The design principles explain **how product decisions should be judged**.  
The OpenAPI stub explains **the current API surface used by the MVP/demo flow**.

---

## Interpretation Rules

- Earlier PRDs should be treated as historical evolution records.
- v0.8 documents should be treated as the current product foundation.
- When earlier PRDs and v0.8 documents differ, prefer the v0.8 documents for current design judgement.
- Earlier PRDs are still useful for understanding why the product evolved the way it did.

---

## Current Product Summary

At v0.8, AI Opportunity Radar is defined as:

- a private diary / notebook-like observation product
- focused on low-friction real-fragment capture
- centered on observation before management
- supported by light AI acknowledgement and follow-up
- structured around Today / Weekly / Memory / Opportunity layers
- aimed at helping users identify promising AI / automation opportunities in real life

Future additions such as goals, tasks, schedules, and review are allowed only if they remain lightweight and subordinate to the core observation-and-judgement flow.
