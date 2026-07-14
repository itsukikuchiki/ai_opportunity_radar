# Trace And Evidence

Last updated: 2026-07-12

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
| Journey evidence drilldown | User-visible source explanation. |
| Journey Pro L3 evidence/follow-up | Implemented bounded raw SignalCard evidence; follow-up opens from a real SignalCard ID. |
| Candidate evidence sheet | Implemented concise explanation for why an action/experiment candidate appeared; device accessibility QA remains. |
| Trace Debug | Dev-only table reader for Signal -> Weekly / Journey / Experiment / PipelineRun. |

Trace Debug also exposes `LegacyFallbackMonitor` counters. Reset counters, reproduce a flow, refresh the page, and check whether legacy fallback reads are still non-zero before deleting fallback code.

## Rules

- Trace links should point to real source rows.
- An internal Observation is not a user fact. Only an explicitly added
  `ai_predicted` SignalCard can enter the user-visible fact chain.
- `MicroActionCandidate` and `ExperimentCandidate` should link to eligible
  SignalCards and may cite traceable Observation context only while its source
  SignalCards remain eligible. User confirmation creates a new SignalCard; it
  does not convert the Observation into a confirmed fact.
- Adoption should create `origin_candidate` links from the formal action or
  experiment to its candidate; it must not rewrite the candidate as the formal
  object.
- Candidate and reflection UI should answer “why am I seeing this?” with a
  concise source summary and optional evidence drilldown.
- Old data can use fallback evidence, but should not fabricate source certainty.
- Deletion, privacy exclusion, and inaccurate confirmation should mark related trace links inactive.
- If adopted content loses source evidence later, keep the user's action or
  experiment history but mark the source relationship changed and exclude the
  missing evidence from new AI claims.
- Unadopted candidates become stale immediately when their eligible source hash
  changes. The UI announces regeneration, briefly debounces rapid edits, and
  replaces the group in place when the new `ready` snapshot arrives.
