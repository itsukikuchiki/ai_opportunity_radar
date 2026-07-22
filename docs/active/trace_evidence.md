# Trace And Evidence

Last updated: 2026-07-22

Trace/evidence is the active debugging and trust layer for AI output.

## Flow

```text
Insight / Observation / Reflection / Rollup
  -> trace_links
  -> Signal / Feedback / Weekly / Experiment source
```

## Surfaces

| Surface | Role |
| --- | --- |
| Journey source-Signal drilldown | User-visible source explanation. Selected-month date nodes open the canonical Diary date projection; quick-experiment/goal milestones may open the corresponding read-only object detail. |
| Journey Pro three-month change | Keeps internal trace links for generation and invalidation, but exposes no source-Signal list, date drilldown or AI follow-up section. |
| Candidate source-Signal sheet | Concise explanation for why a quick-experiment/goal candidate appeared; underlying MicroAction/Experiment candidate sources remain separately traceable. |
| Trace Debug | Dev-only table reader for Signal -> Weekly / Journey / Experiment / PipelineRun. |

Trace Debug also exposes `LegacyFallbackMonitor` counters. Reset counters, reproduce a flow, refresh the page, and check whether legacy fallback reads are still non-zero before deleting fallback code.

## Rules

- Trace links should point to real source rows.
- A saved SignalCard and saved progress/review/lifecycle event are immutable
  source rows. Trace and evidence surfaces are read-only and never offer a
  content edit path; deletion/privacy exclusion changes link activity without
  rewriting the source fact.
- An internal Observation is not a user fact. Only an explicitly added
  `ai_predicted` SignalCard can enter the user-visible fact chain.
- `MicroActionCandidate` (user-facing quick try) and `ExperimentCandidate`
  (user-facing goal) should link to eligible
  SignalCards and may cite traceable Observation context only while its source
  SignalCards remain eligible. User confirmation creates a new SignalCard; it
  does not convert the Observation into a confirmed fact.
- Adoption should create `origin_candidate` links from the formal action or
  experiment to its candidate; it must not rewrite the candidate as the formal
  object.
- Candidate and reflection UI should answer “why am I seeing this?” with a
  concise source-Signal summary and optional source drilldown. Internal docs
  and debug tools may still call this evidence; user-visible copy may not.
- Old data can use fallback evidence, but should not fabricate source certainty.
- Deletion, privacy exclusion, and inaccurate confirmation should mark related trace links inactive.
- If adopted content loses source evidence later, keep the user's action or
  experiment history but mark the source relationship changed and exclude the
  missing evidence from new AI claims.
- Unadopted candidates become stale immediately when their eligible source hash
  changes. The UI announces regeneration, briefly debounces rapid source-state
  changes, and replaces the group in place when the new `ready` snapshot
  arrives. Here
  source-hash changes come from new facts or deletion/policy/eligibility state,
  not from editing an existing fact.
