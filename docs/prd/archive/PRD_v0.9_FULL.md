# AI Observation Product PRD v0.9 FULL

## 1. Product Definition

AI-assisted observation app that helps users capture daily signals,
detect patterns, identify friction, and suggest actionable improvements.

------------------------------------------------------------------------

## 2. Core Flow

Record → AI Response → Signal Accumulation → Pattern Detection →
Proposal → User Decision → Follow-up → Re-evaluation

------------------------------------------------------------------------

## 3. Core Concepts

### Signal

Single user entry. Raw observation.

### Pattern

Repeated signals forming a recognizable behavior.

### Friction

Pattern causing repeated effort or energy drain.

### Proposal

Action suggestion generated from patterns/friction.

### Follow

Tracking user response and outcome of proposal.

------------------------------------------------------------------------

## 4. Product Structure

-   Today → Daily capture & timeline
-   Weekly → Weekly interpretation & decision
-   Journey → Long-term trajectory
-   Me → Preferences & system settings

------------------------------------------------------------------------

## 5. Today Page (Spec)

### Modules

-   Header (date + focus)
-   Input box ("记一下")
-   Timeline (3--5 recent signals)
-   AI short response per item
-   Daily Observation summary

### Rules

-   No manual categorization
-   Every entry gets AI response
-   Timeline is main visual

------------------------------------------------------------------------

## 6. Weekly Page (Spec)

### Modules

-   Header (week + count)
-   Weekly overview (2--4 lines)
-   State visualization (max 2 charts)
-   Patterns
-   Frictions
-   Proposals (2--3 max)
-   Follow-up section

### Proposal Actions

-   Try
-   Later
-   Not suitable

------------------------------------------------------------------------

## 7. Journey Page (Spec)

### Modules

-   Overview (30-day summary)
-   Patterns
-   Frictions
-   Improvements
-   Ongoing observations

### Role

Long-term understanding, not archive.

------------------------------------------------------------------------

## 8. Proposal Lifecycle

### Generate

From repeated signals/patterns/frictions

### States

-   Try → enter follow-up
-   Later → lower priority
-   Not suitable → return to observation pool

### Follow-up

-   Helpful
-   Still observing
-   Not useful

### Re-propose

Only when: - stronger evidence - clearer suggestion

------------------------------------------------------------------------

## 9. UX Rules

-   One main action per screen
-   No dashboard overload
-   Light AI responses
-   Human-readable language
-   Always allow "no conclusion"

------------------------------------------------------------------------

## 10. Default Rules

-   Today shows 3--5 items
-   Weekly suggestions: 2--3
-   Language follows system
-   Preferences editable anytime

------------------------------------------------------------------------

## 11. Visual Principles

-   Light, calm, structured
-   Clear hierarchy
-   Minimal decoration
-   Mobile-first

------------------------------------------------------------------------

## 12. Scope

### In

-   Full core loop
-   Proposal system
-   Timeline UI
-   Weekly interpretation

### Out

-   Task management
-   Calendar
-   Social features

------------------------------------------------------------------------

## 13. Success Criteria

-   User records ≥1 signal
-   Receives AI response
-   Understands Weekly
-   Engages with proposal

------------------------------------------------------------------------

End of PRD v0.9 FULL
