# AI Observation Product
## PRD Phase 2 v1

---

## 1. Document Goal

This document defines the **Phase 2 product scope** for the AI observation app after Phase 1.

Phase 2 focuses on two goals:

1. **repair and strengthen the Phase 1 experience**
2. **introduce premium features with clear user-perceived value**

This document should be read together with:

- `PRD_v0.8_foundation.md`
- `PRD_v0.9_FULL.md`
- `Product_Design_Principles_v0.8.md`

Phase 2 does not replace the product foundation.  
It extends the product in a way that remains aligned with the existing core:

- observation first
- private by default
- low-friction daily capture
- light AI support
- weekly interpretation
- long-term trajectory understanding

---

## 2. Phase 2 Product Summary

Phase 1 validated the basic product loop:

**Record → AI Response → Signal Accumulation → Weekly / Journey Interpretation**

Phase 2 expands this loop in two directions:

### 2.1 Experience reinforcement
The product must become more reliable, more coherent, and more emotionally convincing.

This includes:
- better AI response quality in Today
- stable Weekly generation after day 2
- correct Journey clue accumulation
- clearer continuity across time

### 2.2 Premium value construction
The product must provide premium value that is:
- easy for users to feel
- naturally aligned with the product identity
- clearly separated from free basic usability

Phase 2 premium value will focus on:
- **companionship depth**
- **interpretation depth**
- **personal trajectory / notebook depth**

---

## 3. Why Phase 2 Is Needed

Phase 1 established the page structure and the basic loop:

- Today for capture
- Weekly for interpretation
- Journey for long-term trajectory
- Me for settings and preferences

However, there are still important gaps:

### 3.1 Experience gaps
- Today AI replies still feel too fixed or too narrow in emotional range
- Weekly may still fail to show meaningful data after the user has already used the app for multiple days
- Journey clue accumulation may remain at zero even when the user has already generated enough signals

These issues weaken product trust.

### 3.2 Value gap
The product already has a meaningful free foundation, but the premium layer is not yet clearly defined.

A Phase 2 premium layer must not lock basic usability.  
Instead, it must enhance:
- continuity
- depth
- interpretation
- companionship
- personal archive value

This is consistent with the existing product quality bar and structural simplicity rules.

---

## 4. Phase 2 Objectives

### 4.1 Primary Objective
Make the product feel more real, more continuous, and more worthy of long-term private use.

### 4.2 Secondary Objectives
- improve AI response quality without drifting into full companion chat
- make Weekly reliably useful from early usage days
- make Journey visibly accumulate clues over time
- introduce premium features that users can immediately understand
- maintain product simplicity and avoid dashboard overload

### 4.3 Non-Objectives
Phase 2 is **not** intended to turn the product into:
- a full chat companion product
- a task manager
- a planning dashboard
- a heavy analytics system
- a searchable archive product

This remains aligned with the v0.8 scope boundaries and design constraints.

---

## 5. Core Product Principles for Phase 2

Phase 2 must continue to follow the current product philosophy:

### 5.1 Observation first, not management first
New features must deepen observation and interpretation, not replace them with management workflows.

### 5.2 Real fragments first
Users still write in low-friction, natural language.  
No additional structure should be required for premium features.

### 5.3 Private by default
Phase 2 features remain private, intimate, and low-pressure.

### 5.4 Light AI acknowledgement remains the default
Even when premium interaction depth increases, the product must not become long-form open-ended companion chat.  
Premium conversation should stay anchored to a user’s recorded fragment.

### 5.5 Explanation over quantity
Weekly and Journey must become more useful, but not longer or noisier.  
This principle is especially important for chart upgrades and premium analysis.

---

## 6. Phase 2 Product Strategy

Phase 2 has two parallel tracks.

### 6.1 Track A: Foundation strengthening
These are not optional. They are basic product trust work.

- Today AI reply upgrade
- Weekly data generation logic repair
- Journey clue generation logic repair
- Weekly chart upgrade for clearer interpretation

### 6.2 Track B: Premium layer
These create the first meaningful paid tier.

- Today light dialogue mode
- Journey notebook view
- Deep Weekly / Monthly interpretation
- AI response style switching
- Structured self-review modules

---

## 7. Updated Product Flow in Phase 2

### 7.1 Free Core Flow
1. User writes a fragment in Today
2. AI gives a higher-quality short response
3. Signals accumulate
4. Weekly reliably generates interpretation after early usage
5. Journey gradually accumulates clues and trajectory structure
6. User begins to feel continuity and understanding

### 7.2 Premium Enhanced Flow
1. User writes a fragment
2. AI responds
3. User may continue with a short premium dialogue
4. Weekly gives deeper interpretation and richer chart reading
5. Journey allows notebook-like historical review
6. Over time, deeper personal structure becomes visible

---

## 8. Page-Level Changes in Phase 2

---

## 8.1 Today

### Existing Role
Capture daily fragments and provide light acknowledgement.

### Phase 2 Role
Today remains the main daily entry point, but the response quality and interaction depth are improved.

### New / Updated Features

#### A. Today AI Reply Upgrade
**Type:** Free base + premium-enhanced foundation  
**Goal:** Make responses feel more natural, more emotionally accurate, and more context-aware.

##### Requirements
- better detection of emotional tone
- better recognition of common life contexts
- less template repetition
- better matching between entry content and AI response
- better matching between entry content and “today’s small observation / try this first” style outputs

##### Expected outcome
Users should feel:
- the reply matches what they actually wrote
- the system can respond to both negative and positive emotional entries
- the AI is supportive without feeling generic

#### B. Today Light Dialogue Mode
**Type:** Premium  
**Goal:** Extend Today from single-turn acknowledgement into lightweight, fragment-centered dialogue.

##### Requirements
- user can respond to an AI reply
- AI can continue for a short multi-turn exchange
- interaction remains anchored to the current entry
- do not become open-ended general chat

##### Recommended interaction shape
Offer lightweight follow-up actions such as:
- continue
- help me sort this out
- what am I really stuck on
- what should I do first today
- no advice, just help me see it clearly

##### Constraint
This must still respect the original principle that the product is not a long-form companion chatbot.

---

## 8.2 Weekly

### Existing Role
Transform recent fragments into stage-level judgement.  
Weekly is interpretive, not report-like.

### Phase 2 Role
Weekly becomes more reliable and more explainable, while remaining concise.

### New / Updated Features

#### A. Weekly Data Generation Logic Repair
**Type:** Free  
**Goal:** Ensure Weekly shows meaningful content after day 2 and does not remain empty when enough user data already exists.

##### Requirements
- verify time-range logic
- verify signal aggregation logic
- verify fallback logic
- avoid blank Weekly states when there is usable data
- support lightweight Weekly even with relatively small amounts of input

##### Minimum valid free Weekly state
Even with limited data, Weekly should still be able to show:
- a basic overview
- a chart
- one core observation
- one small suggested direction

#### B. Weekly Composite Chart Upgrade: “Signals & State”
**Type:** Free base + premium-enhanced reading  
**Goal:** Replace the current single-layer signal chart with a more meaningful one-chart overview, without increasing report length.

##### Design
A single combined chart:
- **bar layer** = signal intensity / recording density
- **line layer** = emotional or state trend across the week

##### Purpose
Allow the user to understand at a glance:
- which days were high-signal days
- which days had lower or higher overall state
- whether activity and emotional state moved together
- where the key weekly turning points were

##### Difference from the old signal chart
The old chart mainly showed “how much signal exists.”  
The new chart shows both:
- **how much happened**
- **how the week felt / moved**

##### Free layer
- show the weekly combined trend

##### Premium-enhanced layer
- highlight key turning points
- highlight low points / rebound points / high-pressure days
- provide stronger explanatory reading tied to deeper Weekly interpretation

#### C. Weekly Key Issue
**Type:** Free  
**Goal:** Surface the most important issue or theme that became visible this week.

##### Requirements
AI should identify:
- the core issue most worth noticing this week
- whether it is more about energy, rhythm, pressure, boundary, emotion, or repeated friction
- one lightweight next observation direction

##### Why free
This is now considered part of the product’s basic interpretive promise, not a premium-only layer.

##### Constraint
It must remain concise and not become long-form analysis.

#### D. Deep Weekly / Monthly
**Type:** Premium  
**Goal:** Provide a richer and more continuous interpretation layer for paying users.

##### Deep Weekly may include
- more complete pattern analysis
- multi-theme structure when justified
- clearer distinction between surface events and underlying pressure
- stronger “what to watch next” guidance

##### Monthly may include
- month-level change trend
- repeated themes
- what improved
- what stayed unresolved
- what became clearer over time

##### Constraint
Even premium depth should remain readable and not become dashboard overload.

---

## 8.3 Journey

### Existing Role
Represent long-term trajectory and learned structure, not raw archive.

### Phase 2 Role
Journey remains the long-term understanding layer, but now gains a more tangible sense of accumulation.

### New / Updated Features

#### A. Journey Clue Logic Repair
**Type:** Free  
**Goal:** Ensure clues accumulate in a believable and visible way, instead of remaining at zero after multiple days of use.

##### Requirements
- review clue thresholds
- support weak clues, repeated clues, and stable clues
- verify time-window logic
- improve display language when evidence is still early

##### Suggested clue levels
- weak clue
- repeated clue
- stable pattern

##### Display principle
Avoid showing only “0 clues.”  
Prefer growth language such as:
- 1 light clue detected
- still observing
- a clearer trajectory may appear after more days

#### B. Journey Notebook View
**Type:** Premium  
**Goal:** Give paying users a notebook-like way to revisit their daily entries over time.

##### Requirements
- notebook button entry in Journey
- day-based historical reading experience
- daily entries with AI responses
- emphasis on intimacy, reflection, and continuity

##### Constraint
This should feel like a quiet personal notebook view, not a searchable data archive.

---

## 8.4 Cross-Page / System Layer

#### A. AI Response Style Switching
**Type:** Premium  
**Goal:** Let users choose a response tone that better fits their preference.

##### Suggested starter styles
- gentle
- clear-minded
- structured

##### Rollout suggestion
Start with Today only, then extend later if needed.

#### B. Structured Self-Review
**Type:** Premium  
**Goal:** Turn scattered recent observations into one structured thematic review.

##### Example themes
- what I’ve been repeatedly stuck on lately
- what has been draining me recently
- what has quietly improved
- what I keep caring about these days

##### Boundary
This is not just repeating the free daily or weekly summary.  
It is a more intentional structured synthesis.

---

## 9. Free / Premium Boundary

A strong Phase 2 product requires a clear distinction between:
- **basic validity**
- **paid enhancement**

### 9.1 Free Must Guarantee
The following belong to basic product validity and should remain free:

- Today capture and basic AI response
- improved AI reply quality
- Weekly generation after early usage
- Journey clue accumulation
- basic Weekly combined chart
- Weekly key issue
- basic observation and one lightweight next-step direction

### 9.2 Premium Should Enhance
The following are appropriate premium features:

- Today light dialogue mode
- premium chart interpretation enhancements
- Deep Weekly / Monthly
- Journey notebook view
- AI response style switching
- structured self-review

This boundary preserves the product’s core promise while creating meaningful paid depth.

---

## 10. Scope Definition for Phase 2

### 10.1 In Scope
- Today AI reply upgrade
- Today light dialogue mode
- Weekly data logic repair
- Weekly combined chart upgrade
- Weekly key issue
- Deep Weekly / Monthly
- Journey clue logic repair
- Journey notebook view
- AI response style switching
- structured self-review

### 10.2 Out of Scope
The following remain out of scope for Phase 2:
- search
- tagging system
- export
- public sharing
- heavy chart expansion
- task management
- calendar planning
- long-form open companion chat

This is consistent with the current product’s scope control and anti-drift rules.

---

## 11. Success Criteria for Phase 2

Phase 2 is successful if:

### 11.1 Experience success
- Today responses feel noticeably less generic
- Weekly shows meaningful content from early usage instead of staying blank
- Journey clues visibly accumulate
- the product feels more continuous and more trustworthy

### 11.2 Premium success
- users clearly understand what premium unlocks
- premium features feel like depth, not paywalling basic usability
- light dialogue, deeper Weekly, and notebook view feel like meaningful upgrades

### 11.3 Identity success
The product still feels:
- private
- thoughtful
- low-pressure
- insightful
- structurally simple

And does **not** feel like:
- a dashboard
- a PM tool
- an always-chatting companion bot

This preserves the original product personality.

---

## 12. Recommended Delivery Order

### Phase 2A
Foundation + high-impact visible upgrade
- Today AI reply upgrade
- Weekly data logic repair
- Journey clue logic repair
- Weekly combined chart upgrade
- Weekly key issue

### Phase 2B
Premium core value
- Today light dialogue mode
- Journey notebook view
- Deep Weekly
- premium chart reading enhancements

### Phase 2C
Premium personalization
- Monthly
- AI response style switching
- structured self-review

---

## 13. Final Product Statement for Phase 2

In Phase 2, the AI observation product remains a private notebook-like system for capturing real-life fragments and gradually turning them into understanding.

Phase 2 strengthens the product by improving the quality and reliability of its core experience, especially in Today, Weekly, and Journey. At the same time, it introduces a premium layer that deepens companionship, interpretation, and personal trajectory review without breaking the product’s observation-first identity.

The result should be a product that feels more trustworthy in daily use, more meaningful over time, and more clearly worth paying for—while still remaining gentle, simple, and private.
