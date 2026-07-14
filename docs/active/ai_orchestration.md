# AI Orchestration

Last updated: 2026-07-12

This document is the active product contract for AI stages. SignalPath
organizes AI by problem depth, not by model name. Model choice may change
without changing the user-visible object boundaries below.

Status vocabulary follows [App Design](app_design.md): **Implemented**,
**Partial**, **Target**, and **Compatibility**.

## 1. Non-Negotiable Boundaries

1. User input is saved before optional AI enrichment begins.
2. Only a timeline-confirmed, eligible `SignalCard` is a user fact.
3. An `Observation` is an internal L2 hypothesis with evidence links. It is not
   a user fact, does not increment any three-signal gate, and cannot enter the
   timeline without a separate editable user confirmation that creates a
   `SignalCard`.
4. A candidate is not an adopted object. Only explicit adoption creates a
   `MicroAction` or `LifeExperiment`.
5. AI may rank eligible evidence and candidates; it may never bypass
   eligibility, period, privacy, entitlement, or deletion rules.
6. `Schedule` and `Goal` are compatibility-only and must not be active AI
   inputs, threshold facts, or generated outputs.
7. A Today acknowledgement or Pro light dialogue is L1 Attune. It is not an
   Observation, candidate, reflection, or report evidence. Pro access never
   upgrades a light conversation to L2/L3 by itself.

## 2. Level Model

| Level | Product role | Typical output | User control | Current status |
| --- | --- | --- | --- | --- |
| L1 Parse | Reduce capture and reading effort. | title, tags, emotion, short summary | Original input is already saved; user may edit or ignore enrichment. | **Implemented baseline** |
| L1 Attune | Catch the user's immediate emotion and offer light feedback within one record. | 1-3 sentence acknowledgement, concrete reflection, at most one low-pressure question/invitation | User may ignore it; Pro may open a short session from one selected SignalCard. | **Implemented baseline**; provider-level regional crisis resources remain Target |
| L2 Reason | Surface a possible pattern from eligible facts. | evidence-backed `Observation` / AI prediction | User rates accurate / somewhat / inaccurate. Accurate or somewhat opens a separate editable “add to timeline?” step; inaccurate creates no fact. | **Implemented infrastructure; boundary audit required** |
| L2 Plan | Offer low-cost next steps after a period gate. | ranked MicroAction or Experiment candidates | User may edit and adopt zero, one, or several candidates. | **Implemented baseline**; device QA pending |
| L3 Reflect / synthesize | Explain Weekly and Journey patterns at the depth allowed by the product surface. | versioned reflection, evidence, effective methods, adjustment direction | User reads, drills into evidence, and may act through separate candidate/adoption flows. | Standard Weekly, This Week Deep Read, Free Journey, and Journey Pro evidence surface **Implemented baseline**; independent 28-day Pro interpretation **Target** |

## 3. Save-First L1 Flow

```text
capture draft
  -> explicit user save
  -> create/update SignalCard
  -> evaluate eligibility
  -> enqueue optional enrichment
  -> persist title/tags/summary with version and trace metadata
```

Voice and state sheets may be skipped without a write. Failure, timeout, or
cancellation of AI enrichment must not discard or block the user's saved text.

## 4. L1 Attune: Emotion Acknowledgement And Light Feedback

### Today timeline reply

```text
saved SignalCard
  -> safety/privacy check
  -> L1 Parse
  -> L1 Attune
  -> versioned ai_reply snapshot attached to the same SignalCard
  -> Today timeline
```

The response order is: acknowledge the immediate feeling, reflect the concrete
event, then optionally offer one gentle invitation or one low-pressure
question. It stays within the selected record and uses provisional language
such as "it sounds like", "perhaps", and "if you want". Default length is 1-3
short sentences and no more than one question.

The snapshot is not a new SignalCard, Observation, threshold fact, candidate,
or reflection evidence. If no saved snapshot exists, the reader shows neutral
copy; it must not synthesize a pattern on demand from keywords.

### Pro light dialogue

```text
user selects one SignalCard
  -> entitlement and quota check
  -> selected SignalCard + visible L1 reply + current-session context
  -> L1 Attune short dialogue
  -> session-only responses
```

Pro controls access, context length, and quota only. The default request must
not read hidden L2 Observation fields or use cross-record history. Dialogue is
not written to SignalCard, Observation, candidates, or ReflectionResult. A
future save action must reopen the editable Add-to-timeline gate.

Light feedback is not a MicroAction: it has no three-signal gate, adoption,
candidate page, progress, Weekly projection, or formal-object wording. Suggested
conversation actions are "say a little more", "help me put this into words",
and "give me a little feedback", not "create an action" or "make an
observation".

### Safety branch

L1 Attune may not diagnose physical or mental illness, assign personality,
trauma, attachment, motives, or permanent patterns, promise treatment or
confidentiality, or replace L2/L3 work. Potential immediate-harm language stops
ordinary dialogue and enters a separately localized safety response: check for
immediate danger, encourage local emergency/professional/trusted-person support,
and show verified regional resources. The risk classification is not a user
fact. Policy may mark the saved record `sensitive / do_not_analyze` so it does
not enter planning or synthesis.

## 5. L2 Observation And Timeline Decision

```text
eligible SignalCards
  -> L2 reasoning
  -> Observation + evidence trace
  -> show prediction under Quick Record
  -> user chooses accurate / somewhat / inaccurate
       inaccurate -> zero write and session-only dismissal
       accurate or somewhat
         -> editable confirmation sheet
         -> user chooses add to timeline or cancel
              add -> new SignalCard -> normal eligibility path
              cancel -> no new user fact
```

The rating and the timeline decision are separate UI steps. If the user does
not add the proposal, neither step is persisted as feedback. Editing changes
only the new `SignalCard` payload after confirmed insertion; it must not rewrite
the source `Observation` or its evidence.

Signal Library uses the same confirmation boundary. Library content is a
`SignalCard` reference, not a Small Experiment, Small Action, or standalone
Observation record.

## 6. L2 Candidate Planning

Planning reads only distinct eligible SignalCards inside the user's local
period:

- daily MicroAction gate: at least three eligible SignalCards in the same local
  day;
- weekly Experiment gate: at least three eligible SignalCards in the same local
  week;
- at most three ranked candidates per stable candidate group;
- candidates retain source period, evidence links, focus context, prompt/model
  version, and rank;
- planning reads a bounded `EnergyBudgetSnapshot`: daily capacity plus weekly
  constraints for MicroActions, and weekly budget plus effective feedback for
  LifeExperiments;
- energy adjusts content, duration, cadence, switching cost, buffer, difficulty,
  rank, and rationale; it never replaces the gate or hides otherwise eligible
  facts;
- `unknown` stays light and reversible, very-low/low favors recovery, boundary,
  buffer, or reduced-switching options, and higher capacity may allow a deeper
  option while retaining a light alternative;
- user may adopt `0..n`; each adoption creates one formal object idempotently;
- unadopted candidates may be superseded after source invalidation, while
  adopted objects keep historical provenance.

The shared grouped/ranked read model, daily MicroAction generation, dedicated
selection pages, multi-adoption, and structured daily/weekly Energy input to
both plural generators are the **Implemented baseline**. Legacy single-candidate
reads remain compatibility paths; release acceptance still requires device and
migration regression.

## 7. L3 Reflection

### Weekly

Weekly reads a bounded local-week snapshot of eligible SignalCards, adopted
MicroActions, formal LifeExperiments, and their own feedback streams. It may use
traceable Observations as derived context, never as extra facts. The next-week
candidate hub is a separate output from the weekly reflection.

The standard Weekly report and Pro “This Week Deep Read” are publishable only
after 3 distinct eligible SignalCards exist in the current user-local
Monday-Sunday week. Before that state, the UI shows readiness progress and no
Weekly interpretation. The Pro surface is called “This Week Deep Read.”

### Journey

Free Journey always keeps the user's timeline, fragments, SignalCard local-date
monthly grid, curve, and available evidence readable. The grid is an in-app
aggregation and does not read the system Calendar. Its synthesized monthly
report starts after the monthly evidence threshold. Journey Pro L3 is a separately discoverable,
entitlement-gated **Implemented baseline** at `/memory/pro-l3` with:

- exact `14/7/2` readiness;
- verifiable 28-day statistics and two local-week fact comparison;
- an existing Journey summary when available;
- raw eligible SignalCard evidence;
- follow-up opened from a real SignalCard ID;
- insufficient-data, loading, offline, and error states.

The page does not run an independent versioned 28-day interpretive generator.
If no existing Journey summary is cached, it shows statistics and source
evidence only. A new traceable 28-day L3 `reflection_result` generator remains
**Target** and must not be implied by factual comparison copy.

This Week Deep Read must not be presented as the Journey Pro report.

Free Journey becomes publishable after 7 distinct eligible SignalCards across
3 local dates in the current calendar month. Journey Pro L3 additionally needs
14 distinct eligible SignalCards across 7 local dates and 2 Monday-Sunday week
buckets in the latest 28 days. Feedback, Observations, candidates, and AI text
may enrich an eligible run but never satisfy its SignalCard threshold.

## 8. Orchestration Inputs

Every run receives an explicit contract rather than scanning arbitrary history:

```text
user_id
local_period_start / local_period_end
timezone
eligible_signal_ids
adopted_object_ids and bounded feedback rollups when relevant
focus_domain_ids in user-defined order
energy_snapshot_id / energy_snapshot_hash / capacity_band when planning
privacy / entitlement capabilities
pipeline purpose and output schema version
```

Focus domains shape ranking and wording but do not exclude otherwise eligible
signals by default. The current local multi-select implementation is
**Implemented**; an ordered remote identity model is **Target**.

## 9. Storage And Traceability

| AI output | Active storage | Required provenance |
| --- | --- | --- |
| L1 Parse enrichment | SignalCard enrichment fields / pipeline output | source SignalCard, prompt/model/schema version |
| L1 Attune timeline reply | SignalCard `ai_reply` versioned snapshot | exactly one source SignalCard, safety/policy result, prompt/model/schema version |
| Pro L1 Attune dialogue | session memory only; usage counters may store token/cost totals | selected SignalCard id and current-session context; no dialogue-to-evidence link |
| Daily reflection | `reflection_results` with daily snapshot source | bounded source period and trace links |
| Observation / judgement | `observations` | evidence links to eligible SignalCards; no fact status |
| MicroAction candidate | `candidate_groups` + `micro_action_candidates` | candidate group, rank, source period, trace links, energy snapshot/hash, version |
| Experiment candidate | `candidate_groups` + `experiment_candidates` | candidate group/rank, source period, trace links, energy snapshot/hash, version |
| Weekly reflection | `reflection_results` with `source_type = weekly_snapshot` | bounded week and cited evidence |
| Journey reflection | `reflection_results` with `source_type = journey_snapshot` | bounded month/range and cited evidence |
| Journey Pro evidence projection | no new AI storage; bounded `JourneyProReportModel` read | latest-28-day eligible SignalCards, readiness, local-week buckets, existing Journey summary |
| Independent 28-day Pro interpretation | future versioned `reflection_results` output | **Target:** dedicated input hash, pipeline version, and evidence links |
| Pipeline execution | `pipeline_runs` | purpose, input fingerprint, versions, timing, result/error |

Adoption creates an `origin_candidate` link from the formal object; it does not
turn the candidate row itself into the formal object. See
[Trace and Evidence](trace_evidence.md).

## 10. Invalidations And Failure Behaviour

- Deleting, excluding, or materially editing an upstream SignalCard marks
  dependent Observations/reflections stale and immediately transitions the
  affected unadopted candidate group through `stale -> regenerating`. The UI
  announces the update, briefly debounces rapid edits, and replaces the group
  in place when `ready` arrives.
- Falling below a three-signal gate hides/invalidates unadopted candidates.
  Adopted objects remain as user history with their source provenance.
- A relevant explicit state, effective action/experiment feedback, or allowed
  external-hint version change rebuilds the bounded Energy Budget snapshot.
  If its hash changes, dependent unadopted candidate groups use the same
  immediate `stale -> regenerating -> ready` replacement flow.
- Prompt, model, or output-schema rollout marks older generated outputs stale
  according to the version registry; it must not silently rewrite user facts.
- Offline, timeout, parse, and moderation failures degrade to saved original
  content plus calm retry states.
- All generation and restore/retry paths must be idempotent for the same input
  fingerprint and purpose.

## 11. Product-State Summary

Implemented baseline includes save-first capture, eligibility services,
Observations and trace links, bounded Weekly/Journey reflection storage, daily
and weekly candidate groups, multi-adoption, immediate stale regeneration, and
real per-object `X/7`, plus the Journey Pro L3 evidence/comparison route.

Today acknowledgement and Pro short dialogue now share the L1 Attune contract:
the request is bounded to the selected SignalCard and current session, derived
Observation/try-next inputs are excluded, and immediate-risk language switches
to a safety response. Region-specific verified crisis resources remain Target.

Bounded daily/weekly Energy snapshots and their direct plural-planner inputs
are implemented. Candidate/progress release acceptance remains subject to
device QA. Ordered remote focus context and independent versioned 28-day Pro
interpretation also remain **Target**.
