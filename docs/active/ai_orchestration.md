# AI Orchestration

Last updated: 2026-07-22

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
6. Legacy standalone `Schedule` and `Goal` are compatibility-only and must not
   be active AI inputs, threshold facts, or generated outputs. A user-entered
   `time_use` record is instead a normal structured SignalCard and may enter AI
   stages only through the standard eligibility and privacy contract.
7. A Today acknowledgement or Pro light dialogue is L1 Attune. It is not an
   Observation, candidate, reflection, or report evidence. Pro access never
   upgrades a light conversation to L2/L3 by itself.
8. A saved `SignalCard` and every saved progress/review/lifecycle event are
   immutable facts. AI may attach or supersede versioned derived output, but it
   never edits the canonical user fact. Only current-week/next-week planning
   content may receive a prospective user-authored plan version; prior facts,
   dates, and plan snapshots remain read-only.

## 2. Level Model

| Level | Product role | Typical output | User control | Current status |
| --- | --- | --- | --- | --- |
| L1 Parse | Reduce capture and reading effort. | title, tags, emotion, short summary | Original input is already saved and immutable. The user may ignore derived enrichment; any enrichment refresh is separately versioned and never rewrites the fact payload. | **Implemented baseline** |
| L1 Attune | Catch the user's immediate emotion within one record. | Timeline: one short acknowledgement with no advice/question. Pro chat: acknowledgement by default; one light response only after an explicit request for advice. | User may ignore it; Pro may open a short session from one selected SignalCard. | **Implemented baseline**; device QA pending |
| L2 Reason | Surface a possible pattern from eligible facts. | evidence-backed `Observation` / AI prediction | User rates accurate / somewhat / inaccurate. Accurate or somewhat opens a separate editable “add to timeline?” step; inaccurate creates no fact and immediately replaces the proposal in-session. | **Implemented baseline**; device QA pending |
| L2 Plan | Offer low-cost next steps after a period gate. | ranked MicroAction or Experiment candidates | User may edit proposals and adopt zero, one, or several. After adoption, only current-week/next-week planning content may be versioned prospectively; facts and historical plan versions remain read-only. | **Implemented baseline**; device QA pending |
| L3 Reflect / synthesize | Explain Weekly and Journey patterns at the depth allowed by the product surface. | versioned reflection, internal trace links, effective methods, adjustment direction | User reads the reflection and may act only through separate candidate/adoption flows. | Standard Weekly, text-oriented Weekly Deep Analysis, Free Journey, and factual Journey Pro three-month change are **Implemented baseline**; structured Weekly Deep Analysis remains **Target** |

## 3. Save-First L1 Flow

```text
capture draft
  -> explicit user save
  -> create one immutable SignalCard
  -> evaluate eligibility
  -> enqueue optional enrichment
  -> persist versioned derived title/tags/summary and trace metadata without rewriting the fact
```

For Today text, tapping the default field's check control with non-empty text
is that explicit save; there is no second confirmation sheet. Empty text is
zero-write. Voice, state, and time-use use their dedicated review sheets.

Voice, state, and time-use sheets expose the same `Skip for now` zero-write
action and the same `Save as today's signal` confirmation wording. Time-use
still requires its structured fields; the shared wording does not flatten its
payload. Failure, timeout, or cancellation of AI enrichment must not discard or
block the user's saved text.

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

The ordinary timeline response is one short, natural acknowledgement that
recognizes the immediate feeling or concretely reflects the event. It never
offers advice, asks a question, or invites a next step. It stays within the
selected record and uses provisional language rather than claiming to know the
user. The immediate-harm safety branch below is an explicit exception to the
one-sentence/no-question presentation rule.

The snapshot is not a new SignalCard, Observation, threshold fact, candidate,
or reflection evidence. If no saved snapshot exists, the reader shows neutral
copy; it must not synthesize a pattern on demand from keywords.

Older persisted acknowledgements are not rewritten. Read projections enforce
the same L1 rule: advice, invitations, and questions are hidden and replaced by
a neutral localized acknowledgement grounded only in that SignalCard.
Today and the date-browsable Diary render this same stored/fallback L1 snapshot;
changing the selected diary date never generates a new reply or SignalCard.

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

Pro chat is a plain message stream plus composer, with no quick actions,
automatic summary, or suggested prompts. It acknowledges/responds without
proactively advising or asking a question. Only an explicit request such as
"what should I do?" may receive one gentle, reversible, low-pressure response.
This response is not a quick try or goal: it has no three-signal gate,
adoption, progress, Weekly projection, or formal-object wording.

When a turn contains both a causal question and an explicit request for what to
do, the explicit advice request takes precedence; the response is still limited
to one light, reversible option.

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
  -> after a real Signal is saved, show prediction between Today inputs and timeline
  -> user chooses accurate / somewhat / inaccurate
       inaccurate -> zero write, session-only exclude, immediately show another
       accurate or somewhat
         -> editable confirmation sheet
         -> user chooses add to timeline or cancel
              add -> new SignalCard -> normal eligibility path
              cancel -> no new user fact
```

The rating and the timeline decision are separate UI steps. If the user does
not add the proposal, neither step is persisted as feedback. Editing changes
only the proposal draft before insertion; it must not rewrite the source
`Observation` or its evidence. After insertion, the new `SignalCard` is
immutable and the confirmation editor cannot reopen as a record editor.

Signal Library uses the same confirmation boundary. Library content is a
`SignalCard` reference, not a quick try, goal, or standalone Observation
record. Accurate/Somewhat opens the same editable confirmation
sheet as AI prediction, and only Save as today's signal creates a fact.

An inaccurate AI prediction is excluded only in the current in-memory page
session and immediately replaced by another eligible prediction. This creates
no match-feedback event or account data. A page session allows at most three
replacement operations; rejecting the third replacement ends replacement for
that session and shows a neutral no-new-prediction state. The counter and
exclusion set reset when the user leaves the page. If eligible predictions are
exhausted sooner, the same neutral state appears. Library Inaccurate remains
zero-write without replacement.

The Today surface keeps this dependency order: compact state, Signal inputs,
editable AI-prediction decision, confirmed-fact timeline, then the derived
quick-try/goal feedback section at the bottom. A prediction never appears as a
standalone input button.

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
  constraints for quick tries (`MicroAction` storage), and weekly budget plus
  effective feedback for goals (`LifeExperiment` storage);
- energy adjusts content, duration, cadence, switching cost, buffer, difficulty,
  rank, and rationale; it never replaces the gate or hides otherwise eligible
  facts;
- `unknown` stays light and reversible, very-low/low favors recovery, boundary,
  buffer, or reduced-switching options, and higher capacity may allow a deeper
  option while retaining a light alternative;
- user may adopt `0..n`; each adoption creates one formal object idempotently;
- unadopted candidates may be superseded after source invalidation, while
  adopted objects keep historical provenance.

AI planning never rewrites an adopted object's history. While a quick try or
goal remains in the current-user-local-week or next-user-local-week planning
window, the user may revise only its not-yet-occurred plan definition. That
revision creates a prospective plan version and preserves the formal object,
origin candidate, evidence, earlier versions, and all recorded progress. Past
dates and completed periods accept neither AI nor user edits/backfills.

Privacy/safety checks, eligibility decisions, internal Observations, Energy
Budget snapshots, threshold evaluation, candidate generation/adoption state,
source-change regeneration, AI reply snapshots, feedback/progress, and Diary
read projections never create or increment a SignalCard merely by running.
Only the user's explicit Save-as-today's-signal decision creates a countable
fact.

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

The standard Weekly report and Pro
`Weekly Deep Analysis / 本周深度分析` are publishable only after 3 distinct
eligible SignalCards exist in the current user-local Monday-Sunday week. Before
that state, the UI shows readiness progress and no Weekly interpretation.

The standard Weekly report answers what happened: Signal facts, one traceable
repeated pattern, attempt results, and the sibling Weekly Energy State. Weekly
Deep Analysis does not rewrite those layers in longer prose. It adds only:

- a short headline naming one supported cross-layer relationship;
- a relationship map linking Signal context, repeated pattern, energy state,
  and attempt result through explicitly scoped co-occurrence links;
- a seven-day aggregate overlay locating Signal density, qualitative energy
  state, and whether feedback exists;
- a qualitative support band and a three-part next-week validation direction;
- source Signal IDs and a deterministic Analysis Scope statement.

Weekly Energy State is a deterministic upstream projection, not a category the
L3 model may invent or rename. Every eligible Signal arrives with exactly one
stable state key: orange `draining / 偏耗力`, blue `steady / 平稳`, yellow
`ease / 有余力`, green `recovery / 恢复`, or purple
`boundary_buffer / 边界与余地`. `ease` means spare capacity already exists;
`recovery` means a replenishing process or result. The projection first maps
explicit `energy_level 0 / 1 / 2` to `draining / steady / ease`, then reads the
legacy effect only when necessary (`restoring -> recovery`). If neither exists,
traceable actual cues use the fixed stop-on-match order `boundary_buffer >
recovery > draining > ease`; no match becomes `steady`. L3 may describe how
these states co-occur with a pattern or attempt, but may not output an
`unknown`, gray, sixth category, reassign a Signal, or turn a tie into a model
opinion. Switching and deep focus remain overlapping descriptors rather than
state categories.

The target structured response uses `relationship_nodes`,
`relationship_edges`, `daily_overlay`, `support_band`, `next_validation`,
`source_signal_ids`, `behavior_illustration_key`, and `analysis_scope`. The
current `summary / root_tension / hidden_pattern / next_focus / risk_note`
response remains a compatibility baseline. It must not be presented as if the
structured projection is already implemented.

`root_tension` and `hidden_pattern` are not permission to infer personality,
motivation, an inner cause, or a hidden self. A relationship node or line is
published only when its own source Signal IDs and local-date/count scope are
present. The line says `co-occurred / related`, never `caused`. Legacy
`risk_note` is not headed `Use gently / 温和使用`; the target UI replaces it with
deterministic `Analysis scope / 分析范围` based on actual Signal count, recorded
days, source scope, and the non-causal limitation.

AI does not emit topic shares, numeric model confidence, `3/4`, or generated
mood/friction scores for this UI. Support is relationship-specific:
`forming`, `repeated_this_week`, or `cross_week_supported`. Only the last state
permits a long-term-impact statement. User-visible labels are qualitative and
all source/support wording says `Signal / linked Signal / source Signal`; the
word `evidence` remains internal to trace, audit, and eligibility contracts.

The next-week direction is three compact outputs—`why_try`, `how_to_try`, and
`what_to_watch`—not the user-visible English headings Strategy, Design, and
Development. It proposes a validation direction only; candidate generation,
editing, and adoption remain the separate L2 Plan flow.

Illustration selection is a display projection, not generative free text. The
active catalog distinguishes 24 behavior-pattern keys, 30 review-pattern keys,
and 9 focus keys. AI returns one exact catalog key, never a path. The primary
Weekly behavior key is selected by traceable pattern, distinct dates,
supporting Signal count, then stable key order, and is reused by Weekly Deep
Analysis for the same source hash. Review-pattern images stay with
attempt-result/feedback meaning. Unknown keys resolve to the versioned neutral
`pattern_forming` asset rather than a guessed behavior.

### Journey

Free Journey always keeps the selected month's Signal-only path, factual grid,
quick-experiment/goal trajectory and real state/rhythm projection readable.
The grid is an in-app aggregation and does not read the system Calendar. Its
synthesized monthly report starts after 7 distinct eligible SignalCards across
3 local dates in that natural month.

Journey report generation may read all policy-allowed app data from first use
through the selected month's end: Signals, explicit status/energy projections,
Weekly reflections, quick-experiment attempts and round reviews, goal daily
facts and weekly/whole-round reviews, plan versions and internal Observations.
Only eligible SignalCards in the output month increase readiness. Other data
may add context but never satisfy a Signal threshold.

Journey Pro at `/memory/pro-l3` is an entitlement-gated three-natural-month
change report. It uses the selected month and its two preceding months, reusing
the same monthly fact/readiness projection. It shows monthly Signal, recording
day, domain and five-state energy distributions, then a short conservative
latest-month change only when at least two of the three months individually
meet `7/3`. It does not contain a duplicate quick-experiment/goal section,
analysis/data-range scope, source-Signal list, date drilldown or AI dialogue.

Weekly Deep Analysis remains the separate current-week cross-layer report
gated by 3 Signals; Journey Pro uses only the natural-month projection above.

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
| Pro L1 Attune dialogue | session memory only; usage counters may store token/cost totals | current session context; this is not part of Journey Pro |
| Daily reflection | `reflection_results` with daily snapshot source | bounded source period and trace links |
| Observation / judgement | `observations` | evidence links to eligible SignalCards; no fact status |
| MicroAction candidate | `candidate_groups` + `micro_action_candidates` | candidate group, rank, source period, trace links, energy snapshot/hash, version |
| Experiment candidate | `candidate_groups` + `experiment_candidates` | candidate group/rank, source period, trace links, energy snapshot/hash, version |
| Weekly reflection | `reflection_results` with `source_type = weekly_snapshot` | bounded week and cited evidence |
| Journey reflection | `reflection_results` with `source_type = journey_snapshot` | selected month facts plus history-through-period context hash and trace links |
| Journey Pro three-month change | versioned `reflection_results` output plus three monthly fact projections | selected month and two prior natural months, per-month `7/3` readiness, full-history-through-period context, pipeline version and trace links |
| Pipeline execution | `pipeline_runs` | purpose, input fingerprint, versions, timing, result/error |

Adoption creates an `origin_candidate` link from the formal object; it does not
turn the candidate row itself into the formal object. See
[Trace and Evidence](trace_evidence.md).

## 10. Invalidations And Failure Behaviour

- Deleting, excluding, or changing the eligibility/privacy state of an
  upstream SignalCard marks
  dependent Observations/reflections stale and immediately transitions the
  affected unadopted candidate group through `stale -> regenerating`. The UI
  announces the update, briefly debounces rapid state changes, and replaces the
  group in place when `ready` arrives. Canonical SignalCard content is never an
  editable invalidation source.
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
real per-object progress, plus the legacy Journey Pro route shell that is being
replaced by the three-month change surface.

Today acknowledgement and Pro short dialogue share the implemented L1 Attune
boundary:
the request is bounded to the selected SignalCard and current session, derived
Observation/try-next inputs are excluded, and immediate-risk language switches
to a safety response. The stricter output policy—one no-advice/no-question
timeline sentence, and a gentle Pro response only after an explicit advice
request—is the implemented baseline and requires device regression before
release.
Region-specific verified crisis resources remain Target.

Bounded daily/weekly Energy snapshots and their direct plural-planner inputs
are implemented. Candidate/progress release acceptance remains subject to
device QA. Ordered remote focus context and versioned Journey Pro three-month
change synthesis also remain **Target**.
