# AI Opportunity Radar
## PRD v0.8 Foundation

## 1. Document Goal

This document defines the v0.8 product foundation for AI Opportunity Radar.

It focuses on:
- product scope
- page roles
- experience goals
- feature boundaries
- future extension rules

It should be read together with:
- earlier PRD versions
- API / engineering docs
- implementation notes

This document updates the product foundation rather than replacing the earlier architecture work.

---

## 2. Product Summary

AI Opportunity Radar is a private diary / notebook-like observation system that helps users turn real-life fragments into structured understanding.

The product collects low-friction daily signals, builds memory around them, generates weekly interpretation, and gradually identifies AI / automation opportunities.

---

## 3. Problem Statement

Many users feel:
- their daily life contains repeated manual work
- small frictions consume time and energy
- they suspect AI could help, but do not know where to start
- existing productivity tools ask for too much structure too early

The product solves this by allowing users to record reality first and structure it later.

---

## 4. Product Objectives

### 4.1 Primary Objective
Help users discover where AI or automation can meaningfully reduce friction in their real life.

### 4.2 Secondary Objectives
- reduce the cost of daily recording
- make users feel understood rather than evaluated
- build useful long-term memory from fragmented input
- produce explainable weekly judgement
- support lightweight experimentation over time

---

## 5. User and Usage Context

### 5.1 Primary User
Individual users who:
- repeatedly feel drained by small recurring work
- want a private reflection space
- are curious about practical AI use in their own life
- prefer low-friction writing over formal logging

### 5.2 Context of Use
Likely moments of use:
- after a frustrating daily event
- after repeated information / scheduling / writing work
- during a brief personal reflection moment
- at the end of a day or after a small emotional spike

---

## 6. Core Product Flow

### 6.1 Flow
1. User enters onboarding
2. User writes a real fragment in Today
3. AI provides acknowledgement
4. System optionally asks a follow-up
5. System updates signals / memory
6. Weekly provides stage-level interpretation
7. Memory provides long-term summaries
8. Opportunities emerge as evidence accumulates

---

## 7. Page-level Product Roles

## 7.1 Onboarding

### Purpose
Set the initial observation direction.

### User Outcome
The user understands:
- this is not a heavy check-in app
- one sentence is enough
- the system learns gradually
- follow-up is occasional

### Requirements
- simple starting question
- low friction
- no heavy setup
- no profile overload

---

## 7.2 Today

### Purpose
Capture today’s real fragments.

### User Outcome
The user can quickly record:
- what felt repetitive
- what felt frustrating
- what they wish were easier
- what they emotionally noticed

### Functional Expectations
- free-form text input
- fast entry points
- AI acknowledgement
- occasional follow-up
- daily best action
- recent signals

### UX Rules
- input must feel natural
- no form fatigue
- AI response should feel warm but concise
- the page should reward small entries, not only “good” entries

---

## 7.3 Weekly

### Purpose
Provide a stage-level explanation of recent life signals.

### User Outcome
The user sees:
- what patterns are forming
- what frictions matter most
- what the system currently believes
- what action is worth trying next

### Functional Expectations
- key insight
- patterns
- frictions
- best action
- user feedback on whether the judgement fits

### UX Rules
- must allow empty state
- must not overclaim certainty
- should feel interpretive, not report-like

---

## 7.4 Memory

### Purpose
Accumulate long-term structured understanding.

### User Outcome
The user sees what the system has learned over time.

### Current Categories
- patterns
- frictions
- desires
- experiments

### UX Rules
- not a raw archive
- not a dashboard overload
- should present learned structure, not just stored content

---

## 7.5 Opportunity

### Purpose
Represent opportunities mature enough for user consideration or experimentation.

### User Outcome
The user sees:
- why this may be a real opportunity
- what evidence supports it
- whether it is worth trying

### UX Rules
- should be evidence-based
- should emerge naturally from the rest of the system
- should not feel disconnected from Today / Weekly / Memory

---

## 8. Functional Philosophy by Feature

## 8.1 Diary / notebook-like expression
Included.

The product may explicitly present itself as a private diary / notebook-like space.
This is aligned with the low-friction real-fragment philosophy.

### Constraint
Private first.
Sharing is future optional behavior, not current default behavior.

---

## 8.2 AI emotional acknowledgement
Included.

AI should respond briefly with:
- resonance
- comfort
- concise suggestion
- emotional grounding

### Constraint
Do not turn this into long-form companion chat.

---

## 8.3 Schedule / time-flow awareness
Partially included.

Time allocation is an important observation dimension.
It can support better judgement about friction and repetition.

### Constraint
It must remain an auxiliary layer, not become the product’s primary mode.

### Allowed future forms
- lightweight time block capture
- where time mostly went
- schedule-informed weekly interpretation

### Not allowed for v0.8 core
- heavy calendar workflow
- schedule-first UX
- complex planning system

---

## 8.4 Review content in Weekly / Memory
Partially included.

Review-related content may be introduced, such as:
- intention vs completion
- energy / time distribution
- repeated blockers
- pressure around spending or decisions

### Constraint
Review must support observation and interpretation.
It must not turn Weekly or Memory into a giant life dashboard.

---

## 8.5 Goal / task support
Included only in minimal future form.

### Recommended future shape
- one goal
- a few focus points
- one next experiment
- simple completion state

### Constraint
No heavy PM-style structures.

---

## 9. Scope Definition for v0.8

## 9.1 In Scope
- onboarding
- today capture
- AI acknowledgement
- follow-up flow
- recent signal display
- weekly empty / insight states
- memory summaries
- opportunity foundation

## 9.2 Out of Scope
- full schedule system
- full task manager
- full goal tree
- full finance management
- public sharing network
- heavy analytics dashboard
- long-form AI companionship product

---

## 10. Quality Bar for v0.8

The product is considered valid at v0.8 if:

- the core flow is understandable
- Today is easy to use
- AI responses feel supportive but concise
- Weekly feels interpretive, not noisy
- Memory shows structure, not clutter
- the user can imagine continuing to use it privately
- the system increasingly reveals automation opportunity signals

---

## 11. Product Risks

### 11.1 Product drift toward management
Risk:
The product becomes a task / planning tool.

Mitigation:
New features must justify how they strengthen observation.

### 11.2 Product drift toward companionship
Risk:
The product becomes a chat comfort product.

Mitigation:
Keep AI replies short and observation-oriented.

### 11.3 Product drift toward dashboard overload
Risk:
Weekly / Memory accumulate too much data and lose clarity.

Mitigation:
Prefer explanation over quantity.

### 11.4 Product drift toward public performance
Risk:
Sharing or social exposure reduces honesty of user input.

Mitigation:
Maintain private-by-default principle.

---

## 12. Recommended Next-step Priorities After v0.8

1. improve navigation between Today / Weekly / Memory
2. refine Weekly “rich state” when more signals exist
3. strengthen Opportunity as a result layer
4. improve Memory interpretation quality
5. introduce only lightweight review or goal support if it clearly serves the core model

---

## 13. Final Product Statement

AI Opportunity Radar is a private observation notebook that helps users record real daily fragments with low friction and gradually turns those fragments into structured insight.
By combining brief AI acknowledgement, follow-up questions, weekly interpretation, and long-term memory accumulation, it helps users identify promising AI / automation opportunities in their own life.
Future additions such as schedule awareness, lightweight goals, tasks, or review may be added, but only if they remain subordinate to the core observation-and-judgement workflow.
