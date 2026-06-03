# Signal Path
## Phase 3 Technical Design v1

---

## 1. Document Goal

This document turns the Phase 3 product direction into an implementation-ready technical plan.

Phase 3 upgrades Signal Path from a private AI journal into an **AI Life Management** tool:

**Signal Awareness -> Life Structure -> Energy Budget -> Small Experiment -> Review & Adjust**

The first implementation scope is:

- **V3A: Signal Card data foundation**
- **V3B: Today as Signal Inbox + Diary Timeline**

Large UI changes should not start until the data model, migration path, parser fallback, quota gates, and test acceptance rules in this document are in place.

---

## 2. Phase 3 Product Architecture

### 2.1 Final Navigation

| Page | Role | Main Job |
| --- | --- | --- |
| Today | Signal Inbox + Diary | Capture, confirm, and revisit daily life signals |
| Weekly | Weekly life dashboard | Find the most costly pattern this week and choose one experiment |
| Journey | Long-term life map | See long-term patterns, monthly maps, structure changes, and experiment history |
| Signal Library | Shared signal library | Show curated common life patterns without exposing user raw text |
| Me | Settings / Pro / consent | Manage preferences, language, AI style, Pro, permissions, and privacy |

Monthly will not remain a standalone page. Its analysis ability moves into Journey.

### 2.2 Data Principle

User input must never disappear.

Every Today entry must be preserved as raw input first, then optionally enriched by AI parsing, user confirmation, Weekly inclusion, Journey inclusion, and experiment links.

---

## 3. Signal Card Data Model

### 3.1 Signal Card Purpose

`SignalCard` is the Phase 3 canonical record for Today input and all later analysis.

It replaces the loose relationship between capture, raw memory, AI reply, Weekly, and Journey with a single user-visible object:

**raw input -> parsed signal -> confirmed signal -> daily/weekly/journey usage**

### 3.2 Required Fields

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| id | string | yes | Stable UUID |
| user_id | string | yes | Owner |
| source_type | enum | yes | `text`, `voice`, `one_tap`, `ai_predicted`, `library_saved`, `calendar`, `health` |
| raw_text | text | yes for text-like sources | Original user text or voice transcript. Never overwritten |
| raw_payload_json | json | yes | Stores one-tap values, calendar/health summaries, or source-specific payload |
| ai_reply | text | no | Original Today AI response. Once shown, do not rewrite |
| created_at | timestamptz | yes | Original capture time |
| local_date | date | yes | Date in user's timezone for diary grouping |
| timezone | string | yes | IANA timezone, for example `Asia/Tokyo` |
| language | string | yes | BCP-47 preferred language, for example `ja`, `zh-Hans`, `en` |
| emotion | string | no | Parsed emotion label |
| intensity | integer | no | Suggested range 1-5 |
| scene | string | no | Work, relationship, body, recovery, creation, family, etc. |
| friction | string | no | Interruption, over-scheduling, uncertainty, relationship pressure, etc. |
| positive_signal | string | no | Recovery, freedom, achievement, connection, etc. |
| energy_load | enum | no | `draining`, `restoring`, `neutral`, `mixed` |
| linked_life_chain_stage | json | no | One or more stages from the life chain model |
| confidence_score | float | no | Parser confidence, 0.0-1.0 |
| user_confirmation | enum | yes | `unconfirmed`, `accurate`, `inaccurate`, `edited`, `supplemented` |
| user_correction_json | json | no | User edits to parsed fields |
| included_in_summary | boolean | yes | Whether used in Today Summary |
| included_in_weekly | boolean | yes | Whether eligible/used in Weekly |
| included_in_journey | boolean | yes | Whether eligible/used in Journey |
| linked_experiment_id | string | no | Related Life Experiment |
| parser_version | string | yes | Parser prompt/rules version |
| model_used | string | no | Model used for reply or parser |
| prompt_version | string | no | Prompt version when relevant |
| token_usage_json | json | no | Input/output/cached/reasoning token usage when available |
| privacy_level | enum | yes | `private`, `analytics_eligible`, `abstract_pattern_eligible` |
| schema_version | integer | yes | Start with `1` |
| is_legacy | boolean | yes | True for migrated records |
| migration_status | enum | yes | `native`, `migrated_complete`, `migrated_partial`, `migration_failed` |
| metadata_json | json | yes | Reserved extension field |
| updated_at | timestamptz | yes | Last mutation |

### 3.3 Enum Notes

`source_type` must be explicit because V3 mixes manual text, voice, one-tap state, AI prediction, library saves, and future Calendar/HealthKit signals.

`privacy_level` controls downstream use:

- `private`: can only be used in this user's personal product experience.
- `analytics_eligible`: can be used for aggregate metrics without raw text.
- `abstract_pattern_eligible`: can contribute only to anonymized, abstracted pattern generation after removing raw text and direct identifiers.

### 3.4 Life Chain Stages

The internal chain is:

**external_pressure -> schedule_structure -> attention_switching -> energy_drain -> emotional_response -> behavior_pattern -> outcome_feedback -> long_term_loop**

Today may display only the relevant segment. Weekly and Journey can show longer chains.

---

## 4. V3A Data Migration

### 4.1 Migration Goal

Old Today data must become Signal Cards without losing user history.

Existing records from `captures`, `raw_memories`, and existing AI response fields must be preserved. Missing Phase 3 fields are allowed, but they must be marked clearly as legacy/unconfirmed.

### 4.2 Migration Rules

| Source | Signal Card Mapping |
| --- | --- |
| `captures.content` | `raw_text` |
| `captures.input_mode` | `source_type` when mappable, otherwise `text` |
| `captures.created_at` | `created_at` |
| `raw_memories.signal_type` | `emotion` or `metadata_json.legacy_signal_type` depending on value |
| `raw_memories.scene_type` | `scene` |
| `raw_memories.friction_type` | `friction` |
| `raw_memories.emotion_strength` | `intensity` when numeric-like, otherwise `metadata_json.legacy_emotion_strength` |
| old AI reply | `ai_reply`, unchanged |
| missing parsed fields | null |
| missing confirmation | `unconfirmed` |
| migrated record | `is_legacy = true` |
| partially mapped record | `migration_status = migrated_partial` |

### 4.3 Migration Safety

Migration must be additive:

- Do not delete old tables during V3A.
- Do not overwrite old AI replies.
- Do not collapse multiple user records into one card.
- If parsing historical data fails, still create a Signal Card with raw input.
- Keep `metadata_json.legacy_source_id` and `metadata_json.legacy_source_table` for traceability.

### 4.4 Migration Validation

After migration:

- Every old Today record has a Signal Card.
- Counts match by user and local date.
- Old AI replies are still visible in Diary Timeline.
- Migrated cards show `legacy / unconfirmed` when parsed data is incomplete.

---

## 5. AI Parser And Fallback

### 5.1 Save-First Rule

The backend and client must follow this order:

1. Save raw input locally or server-side.
2. Create or queue a Signal Card.
3. Run parser and AI reply.
4. Attach parsed fields and AI reply.
5. Let user confirm or correct.

AI must never be required for raw input persistence.

### 5.2 Parser Failure Cases

The system must handle:

- network failure
- timeout
- model unavailable
- invalid JSON
- missing required fields
- low confidence
- moderation or safety refusal
- server 5xx

### 5.3 Fallback Behavior

| Failure | Required Behavior |
| --- | --- |
| Parser fails | Keep Signal Card with raw input, `user_confirmation = unconfirmed`, `confidence_score = null` |
| AI reply fails | Show local fallback reply and save it as fallback metadata |
| Output format invalid | Save raw model output in restricted debug metadata when safe, mark parser failed |
| Backend unreachable | Client queues local draft and retries sync |
| Model quota exceeded | Use lower-cost or local fallback, but do not block saving |

### 5.4 Local Fallback Reply

Fallback reply should be short and non-fake:

> I saved this. We can come back to what it means later.

Localized variants are required for supported languages.

---

## 6. Free / Pro Quota And Usage Design

### 6.1 Required Backend Components

V3A should introduce the backend shape even before all quota surfaces are visible:

- `usage_counters`
- `model_usage_logs`
- `quota_gate`
- `cache_keys`
- `feature_entitlements`

### 6.2 Usage Counter Dimensions

Counters should support:

- user_id
- feature_key
- period_type: `daily`, `weekly`, `monthly`
- period_start
- count
- token_input
- token_output
- token_cached_input
- model_used
- source_event_id

### 6.3 Free Quotas

| Feature | Free Quota |
| --- | --- |
| Today high-quality replies | 3 per day |
| Today over quota | local fallback / simplified reply |
| Weekly basic | 1 per week |
| Life Experiment | 1 lightweight experiment per week |
| Journey basic | basic patterns after enough data |

### 6.4 Pro Quotas

| Feature | Pro Quota |
| --- | --- |
| Today high-quality replies | 150 per month |
| Light Dialogue | 30-60 turns per month |
| Deep Weekly | 4 per month |
| Journey / Monthly Life Map | 1-2 per month |
| Misunderstanding Check | 8-12 per month |
| GPT-5.5 deep upgrades | 6-10 per month |

### 6.5 Logging Requirements

Every AI call should log:

- feature_key
- model_used
- parser_version / prompt_version
- input tokens
- output tokens
- cached tokens when available
- latency
- fallback_used
- quota_decision
- cache_hit

Logs must not store raw user text unless explicitly required for debugging and protected by privacy rules.

---

## 7. Energy Budget Scope

Energy Budget should not wait for Calendar / HealthKit.

### 7.1 V3C / V3D Basic Energy Budget

Use internal signals first:

- Today `energy_load`
- friction
- positive_signal
- one-tap energy / mood / pressure / recovery
- Life Experiment feedback

Basic blocks:

- high-drain block
- high-switching block
- deep block
- recovery block
- boundary block
- buffer block

### 7.2 V3G Advanced Energy Budget

Calendar and HealthKit remain later Pro enhancements:

- schedule density
- meeting / task switching
- sleep
- steps
- workouts
- recovery trends

---

## 8. Misunderstanding Check Roadmap

Misunderstanding Check is not part of V3A/V3B, but it is a required roadmap item.

### 8.1 Trigger Points

| Trigger | Page |
| --- | --- |
| Strong emotion in a single Signal Card | Today |
| Repeated relationship friction | Weekly |
| Long-term relationship pattern | Journey |
| Personalized interpretation of shared pattern | Signal Library |

### 8.2 Output Structure

Misunderstanding Check should return:

- facts: what happened
- your interpretation: what the user may be reading into it
- actual hurt / drain point: what may really be needed
- lower-cost expression: one usable sentence

This feature should never tell the user they are wrong. It should help separate event, interpretation, need, and expression.

---

## 9. Signal Library Privacy Rules

Signal Library starts as an official curated library, not an open community.

### 9.1 Hard Privacy Rules

- Never share user raw text.
- Never display user-specific stories as shared content.
- Never let another user infer a specific person's identity, place, workplace, family role, or event.
- Shared cards must use abstracted patterns only.
- User interactions such as "I also have this" and "save to my observation" are private by default.

### 9.2 Initial Content Strategy

V3F should launch with curated common patterns:

- over-scheduled weeks
- recovery debt
- attention switching fatigue
- relationship friction after unclear expectations
- late-night compensation behavior
- weak positive signals such as small freedom, connection, or creative energy

User data can later inform library expansion only through anonymized aggregate pattern counts.

---

## 10. V3A Implementation Tasks

1. Add Signal Card schema and migration.
2. Add migration script from old Today records.
3. Add parser result schema with versioning and confidence.
4. Add save-first capture flow.
5. Add parser and AI reply fallback handling.
6. Add usage counters and AI usage logs.
7. Add quota gate stubs for Today / Weekly / Experiment.
8. Add tests for migration, fallback, quota, and privacy fields.

---

## 11. V3B Implementation Tasks

1. Rework Today data source to read Signal Cards.
2. Add Signal Card UI state: raw input, AI reply, parsed fields, confirmation.
3. Add confirmation actions: accurate, inaccurate, edit, supplement.
4. Add Diary Timeline with all historical Signal Cards.
5. Add local-date grouping by timezone.
6. Add Today Summary inclusion indicators.
7. Add basic current experiment feedback surface.
8. Keep UI quiet and low-pressure.

---

## 12. Acceptance Tests

### 12.1 Data Persistence

- Raw input is saved before AI parsing starts.
- Raw input remains visible after parser failure.
- Raw input remains visible after AI reply failure.
- Voice transcript, one-tap state, and library-saved signals all create Signal Cards.

### 12.2 AI Failure Safety

- Network failure does not lose data.
- Invalid model JSON marks parser failure but keeps the card.
- AI reply fallback is localized and does not pretend deep understanding.
- Retrying parser updates parsed fields without rewriting raw input.

### 12.3 Migration

- Every old Today record becomes one Signal Card.
- Old AI replies are preserved exactly.
- Migrated cards are marked `is_legacy = true`.
- Missing fields are null or legacy metadata, not fabricated.
- Migration can be run idempotently.

### 12.4 Confirmation And Analysis Inclusion

- User confirmation changes `user_confirmation`.
- Edited fields are saved in `user_correction_json`.
- Confirmed signals can enter Weekly and Journey.
- Unconfirmed legacy cards can appear in Diary Timeline but should be treated cautiously in analysis.

### 12.5 Diary Timeline

- Timeline shows all records from the start of app usage.
- Records group by `local_date`, not UTC date.
- Timezone changes do not move historical records unexpectedly.
- AI reply shown in timeline is the reply from that time, not regenerated text.

### 12.6 Multi-Language And Timezone

- `language` and `timezone` are stored on every Signal Card.
- Fallback replies exist for supported languages.
- Today/Weekly boundaries use the user's timezone.

### 12.7 Quota And Usage

- Free Today high-quality replies stop after 3 per local day.
- Weekly basic is gated to 1 per week for Free.
- Pro quota counters are monthly.
- Every AI call records `model_used` and token usage when available.
- Cache hits do not double count paid model usage.

### 12.8 Life Experiment Tone

- No UI text says the user failed a habit.
- Experiment review evaluates whether the life design helped.
- Missed or partial experiments are described neutrally.

### 12.9 Signal Library Privacy

- Shared cards never include raw user text.
- "I also have this" is private.
- Saved library signals become personal Signal Cards with `source_type = library_saved`.

---

## 13. Implementation Guardrails

- Do not start large Today UI redesign until Signal Card migration and save-first flow pass tests.
- Do not use Calendar or HealthKit data before explicit consent.
- Do not use user raw text for Signal Library shared content.
- Do not make Pro gates block basic journaling or old diary access.
- Do not regenerate old AI replies in migration.
- Do not treat quota failure as capture failure.

