# AI Opportunity Radar
## Product Design Principles v0.8

## 1. Purpose

This document defines the product design principles for AI Opportunity Radar v0.8.

It is intended to guide:
- product decisions
- UX decisions
- scope control
- future feature evaluation

This is not an API spec or engineering implementation doc.
It is the design foundation for deciding what belongs in the product and what does not.

---

## 2. Product Definition

AI Opportunity Radar is a private observation product with the outer form of a diary / notebook.

Users record real daily fragments with low friction.
The system responds lightly, asks follow-up questions when needed, builds long-term memory, and gradually identifies promising AI / automation opportunities in the user's real life.

The product is not primarily about managing tasks.
It is primarily about observing reality, recognizing patterns, and surfacing actionable opportunities.

---

## 3. Core Product Promise

The product helps users answer questions such as:

- What am I repeatedly doing?
- What keeps draining my time and energy?
- What kinds of friction show up again and again?
- What do I genuinely wish could become easier?
- Which parts of my life are now ready for AI help or automation experiments?

The product is not trying to answer:
- How many tasks did I complete today?
- How productive was I this week?
- How do I manage every part of my life in one system?

---

## 4. Core Design Principles

### 4.1 Observation first, not management first

The product starts from observing life, not from managing life.

Primary sequence:
1. real fragment
2. signal
3. pattern
4. judgement
5. experiment / next step

Not:
1. task
2. deadline
3. checklist
4. productivity dashboard

Any future goal / task / schedule / review feature must support the observation flow rather than replace it.

---

### 4.2 Real fragments first, not structured input first

Users should be able to write naturally, as if writing:
- a diary
- a private note
- a notebook page
- a SNS draft for themselves
- a small emotional record

The system must accept:
- incomplete input
- emotional input
- fragmented input
- unstructured input

The user does not need to “prepare good data” before the product becomes useful.

---

### 4.3 Private by default

The product is fundamentally a private observation notebook.

Default assumptions:
- entries are private
- expression is low-pressure
- the user is writing for themselves
- there is no performance pressure from being seen

Sharing may exist in the future as an optional extension, but not as a v0.8 core principle.

---

### 4.4 Light AI acknowledgement, not full companion chat

AI should provide light emotional and cognitive support when users write real fragments.

Allowed forms:
- resonance
- brief comfort
- concise suggestions
- a sense of being understood

But AI responses must remain:
- short
- non-dominating
- non-conversational in a long-form sense
- subordinate to the observation-and-judgement workflow

The product is not a pure companion chatbot.

---

### 4.5 Light judgement before strong conclusions

The system should not over-interpret weak evidence.

It must be acceptable for Weekly or Memory to say:
- not enough signals yet
- still observing
- not ready to conclude

Honest uncertainty is better than forced intelligence theater.

---

### 4.6 Simplicity is structural

Simplicity is not only a visual style.
It is a structural rule.

Especially for future modules such as:
- goals
- tasks
- schedules
- review
- finance-related reflection

The product should remain simple unless complexity directly improves the observation core.

---

## 5. Product Personality

The product should feel like:
- private
- thoughtful
- gentle
- insightful
- low-pressure
- emotionally safe

It should not feel like:
- a performance dashboard
- a life admin panel
- a PM tool
- a full social publishing product
- a heavy coaching system

---

## 6. Core Information Architecture

### 6.1 Onboarding
Purpose:
- define the initial observation starting point
- reduce cold-start friction

Onboarding is not a full profile setup.
It only helps the system decide where to look first.

---

### 6.2 Today
Purpose:
- collect real daily fragments
- support immediate capture
- provide light acknowledgement
- ask follow-up when needed
- show current best action
- show recent signals

Today is the main entry point.
It is not a task page.

---

### 6.3 Weekly
Purpose:
- transform recent fragments into stage-level judgement

Weekly answers:
- what is the system currently learning?
- what patterns are forming?
- what frictions matter most now?
- what is the best next action?

Weekly is not:
- a weekly report
- a productivity summary
- a performance page

---

### 6.4 Memory
Purpose:
- accumulate stable long-term structure

Memory is not a raw archive of all entries.
It is what the system has learned from them.

Current long-term categories:
- patterns
- frictions
- desires
- experiments

---

### 6.5 Opportunity
Purpose:
- represent the result layer
- surface opportunities that are mature enough for experimentation

Opportunity should emerge from:
- Today input
- Weekly judgement
- Memory accumulation

It should not become an isolated feature detached from the rest of the system.

---

## 7. Scope Boundaries

## 7.1 Included in v0.8 design philosophy

The following are compatible with the current design philosophy:

- diary / notebook style expression
- private-by-default recording
- AI light acknowledgement / resonance
- observation-driven signal building
- weekly interpretation
- long-term memory accumulation
- simple personal use orientation

---

## 7.2 Allowed as future extensions, but not core skeleton

These are valid future directions if kept lightweight:

- light schedule / time-flow observation
- simple goals
- simple task / next-step support
- reflective weekly review layers
- optional sharing

These must remain subordinate to the core observation model.

---

## 7.3 Not aligned if they become primary

The following create conflict if they become the center of the product:

- heavy task management
- full calendar planning system
- complex project hierarchy
- full expense tracking / finance dashboard
- public social content pressure
- long-form companion chat as primary value

---

## 8. Role of Time, Goals, Tasks, and Review

### 8.1 Time / schedule
Time is a valid observation dimension because many frictions only become meaningful when seen through time allocation.

However:
- time should be an auxiliary observation layer
- not a schedule-first product core
- not a heavy calendar system in v0.8

---

### 8.2 Goals / tasks
Goals and tasks may be introduced only in minimal form.

They should support:
- what the user wants to improve
- what the user wants to test next
- what experiment or next action follows from observation

They should not turn the product into a full management tool.

Recommended future form:
- one goal
- one to three weekly focuses
- one next experiment
- simple completion state

---

### 8.3 Review
Review can be expanded in the future, especially for:
- intention vs reality
- where time / energy went
- what repeatedly blocked progress
- what the user keeps wishing to simplify

But review must remain in service of observation and better judgement, not become a giant life dashboard.

---

## 9. Current Success Criteria

v0.8 is successful if users can:

1. finish onboarding
2. write real fragments in Today
3. receive light acknowledgement and follow-up when appropriate
4. see recent signals
5. see Weekly stage judgement or a valid empty state
6. see Memory summaries accumulating over time

A successful experience should make the user feel:
- this is easy to use
- I do not need to “perform productivity”
- the system is gradually understanding me
- I am starting to see my patterns
- I can imagine real AI help in my daily life

---

## 10. Final Definition

AI Opportunity Radar is a private observation product with the outer form of a diary / notebook.
It allows users to record real-life fragments with low friction, while AI provides light acknowledgement, follow-up questions, weekly interpretation, and long-term memory accumulation.
The product gradually helps users discover patterns, frictions, desires, and experiments that reveal promising AI / automation opportunities.
Time, goals, tasks, and review may enter the system later, but only in lightweight forms that remain subordinate to the core observation-and-judgement flow.
