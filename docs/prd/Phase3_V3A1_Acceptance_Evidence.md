# Signal Path Phase 3
## V3A-1 Acceptance Evidence

Status: conditionally passed, ready to archive after this evidence file.

Scope: backend data foundation only. Today large UI redesign is intentionally not included.

---

## 1. SignalCard Schema Field Matrix

| PRD required field | DB column | ORM field | Nullable/default | Migration source |
| --- | --- | --- | --- | --- |
| id | `signal_cards.id` | `SignalCard.id` | not null, primary key | generated `sig_*` |
| user_id | `signal_cards.user_id` | `SignalCard.user_id` | not null | `captures.user_id` / `raw_memories.user_id` |
| source_type | `signal_cards.source_type` | `SignalCard.source_type` | not null | mapped from `captures.input_mode` or `raw_memories.source` |
| raw_text | `signal_cards.raw_text` | `SignalCard.raw_text` | not null, default empty string | `captures.content` / `raw_memories.content` |
| raw_payload_json | `signal_cards.raw_payload_json` | `SignalCard.raw_payload_json` | not null, default `{}` | source-specific payload; legacy default `{}` |
| ai_reply | `signal_cards.ai_reply` | `SignalCard.ai_reply` | nullable | `raw_memories.metadata_json.acknowledgement` / `ai_acknowledgement` / `response` |
| created_at | `signal_cards.created_at` | `SignalCard.created_at` | not null | original capture/raw memory time |
| local_date | `signal_cards.local_date` | `SignalCard.local_date` | not null | computed from `created_at + timezone` |
| timezone | `signal_cards.timezone` | `SignalCard.timezone` | not null, default `UTC` | request timezone / legacy metadata / `UTC` |
| language | `signal_cards.language` | `SignalCard.language` | not null, default `en` | request language / legacy metadata / `en` |
| emotion | `signal_cards.emotion` | `SignalCard.emotion` | nullable | parser `signal_type` / legacy `raw_memories.signal_type` |
| intensity | `signal_cards.intensity` | `SignalCard.intensity` | nullable | parser/legacy `emotion_strength` mapped to 1-5 |
| scene | `signal_cards.scene` | `SignalCard.scene` | nullable | parser/legacy `scene_type` |
| friction | `signal_cards.friction` | `SignalCard.friction` | nullable | parser/legacy `friction_type` |
| positive_signal | `signal_cards.positive_signal` | `SignalCard.positive_signal` | nullable | parser future field; legacy null |
| energy_load | `signal_cards.energy_load` | `SignalCard.energy_load` | nullable | derived from parser/legacy signal |
| linked_life_chain_stage | `signal_cards.linked_life_chain_stage` | `SignalCard.linked_life_chain_stage` | not null, default `{}` | derived from friction/signal |
| confidence_score | `signal_cards.confidence_score` | `SignalCard.confidence_score` | nullable | parser confidence; null on failed/legacy |
| user_confirmation | `signal_cards.user_confirmation` | `SignalCard.user_confirmation` | not null, default `unconfirmed` | native default / legacy default |
| user_correction_json | `signal_cards.user_correction_json` | `SignalCard.user_correction_json` | not null, default `{}` | user correction API |
| included_in_summary | `signal_cards.included_in_summary` | `SignalCard.included_in_summary` | not null, default false | future inclusion state |
| included_in_weekly | `signal_cards.included_in_weekly` | `SignalCard.included_in_weekly` | not null, default false | future inclusion state |
| included_in_journey | `signal_cards.included_in_journey` | `SignalCard.included_in_journey` | not null, default false | future inclusion state |
| linked_experiment_id | `signal_cards.linked_experiment_id` | `SignalCard.linked_experiment_id` | nullable | future Life Experiment link |
| parser_version | `signal_cards.parser_version` | `SignalCard.parser_version` | not null, default `v3_rules_1` | native parser / `legacy_migration_v1` |
| model_used | `signal_cards.model_used` | `SignalCard.model_used` | nullable | parser/reply model or legacy metadata |
| prompt_version | `signal_cards.prompt_version` | `SignalCard.prompt_version` | nullable | prompt metadata |
| token_usage_json | `signal_cards.token_usage_json` | `SignalCard.token_usage_json` | not null, default `{}` | usage metadata |
| privacy_level | `signal_cards.privacy_level` | `SignalCard.privacy_level` | not null, default `private` | native/legacy default |
| schema_version | `signal_cards.schema_version` | `SignalCard.schema_version` | not null, default `1` | native/legacy default |
| is_legacy | `signal_cards.is_legacy` | `SignalCard.is_legacy` | not null, default false | true for migrated records |
| migration_status | `signal_cards.migration_status` | `SignalCard.migration_status` | not null, default `native` | `native` / `migrated_partial` |
| metadata_json | `signal_cards.metadata_json` | `SignalCard.metadata_json` | not null, default `{}` | tag hint, parser status, legacy trace |
| updated_at | `signal_cards.updated_at` | `SignalCard.updated_at` | not null, default now | database timestamp |

Code:

- ORM: `backend/app/models/signal_card.py`
- SQL migration: `backend/migrations/006_signal_cards_usage.sql`
- Legacy migration logic: `backend/app/repositories/capture_repository.py`

---

## 2. Migration Evidence

### 2.1 Local Staging Copy

Original local DB was read-only, so validation used a safe copy:

`/private/tmp/signalpath_v3a_migration_check.db`

The production database was not touched.

### 2.2 Count Comparison

Output from the staging copy:

```text
MIGRATION_COUNTS
{
  'captures_before': 0,
  'raw_memories_before': 10,
  'signal_cards_before': 0,
  'signal_cards_after': 10,
  'signal_cards_after_second_run': 10
}
```

Per-user migration result:

```text
MIGRATION_RESULTS
{
  'demo_user': {
    'created': 10,
    'skipped': 0,
    'migrated_partial': 10,
    'source_raw_memories': 10
  },
  'metrics-smoke-user': {
    'created': 0,
    'skipped': 0,
    'migrated_partial': 0,
    'source_raw_memories': 0
  }
}
```

Idempotency result:

```text
IDEMPOTENT_RESULTS
{
  'demo_user': {
    'created': 0,
    'skipped': 10,
    'migrated_partial': 0,
    'source_raw_memories': 10
  },
  'metrics-smoke-user': {
    'created': 0,
    'skipped': 0,
    'migrated_partial': 0,
    'source_raw_memories': 0
  }
}
```

### 2.3 Count by `user_id + local_date`

```text
('demo_user', '2026-04-06', 2)
('demo_user', '2026-04-07', 1)
('demo_user', '2026-04-08', 2)
('demo_user', '2026-04-09', 2)
('demo_user', '2026-04-10', 2)
('demo_user', '2026-04-11', 1)
```

### 2.4 Old AI Reply Preservation

The local staging copy had no existing legacy `ai_reply` samples, so a separate staging fixture was used to verify old reply preservation with the same migration function.

```text
REPLY_FIXTURE_BEFORE
{
  captures: 1,
  raw_memories: 1,
  signal_cards: 0
}

REPLY_FIXTURE_MIGRATION
{
  'created': 1,
  'skipped': 0,
  'migrated_partial': 1,
  'source_raw_memories': 1
}

REPLY_FIXTURE_AFTER
{
  captures: 1,
  raw_memories: 1,
  signal_cards: 1
}

REPLY_FIXTURE_SAMPLE
(
  '旧记录：今天很累但撑住了',
  '旧 AI 回复：这一天确实很消耗。',
  1,
  'migrated_partial',
  'unconfirmed'
)

REPLY_FIXTURE_IDEMPOTENT
{
  'created': 0,
  'skipped': 1,
  'migrated_partial': 0,
  'source_raw_memories': 1
}
{
  'signal_cards_final': 1
}
```

Automated test:

- `backend/tests/test_phase3_signal_cards.py::test_legacy_today_records_migrate_to_signal_cards_and_preserve_ai_reply`

---

## 3. Usage Logging Examples

Validation DB:

`/private/tmp/signalpath_v3a_usage_examples.db`

### 3.1 Successful AI Call Log

```text
('usage-success', 'today_high_quality_reply', 'local_rules_reply', 0, 'allowed', '{"reply_status": "generated"}')
```

### 3.2 Fallback Used Log

```text
('usage-fallback', 'today_high_quality_reply', 'local_fallback', 1, 'allowed', '{"reply_status": "fallback"}')
```

### 3.3 Quota Exceeded Log

```text
('usage-quota', 'today_high_quality_reply', 'local_fallback', 1, 'quota_exceeded', '{"reply_status": "fallback"}')
```

Associated quota gate events:

```text
('usage-quota', 'today_high_quality_reply', 'free', 'daily', 3, 0, 'allowed')
('usage-quota', 'today_high_quality_reply', 'free', 'daily', 3, 1, 'allowed')
('usage-quota', 'today_high_quality_reply', 'free', 'daily', 3, 2, 'allowed')
('usage-quota', 'today_high_quality_reply', 'free', 'daily', 3, 3, 'quota_exceeded')
```

### 3.4 Raw Text Privacy Check

```text
RAW_TEXT_IN_MODEL_METADATA_COUNT 0
```

This validates that model usage metadata does not contain the tested raw user phrases.

Automated test:

- `backend/tests/test_phase3_signal_cards.py::test_model_usage_log_strips_raw_text_from_privacy_sensitive_metadata`

---

## 4. Quota Gate Position

### 4.1 Today Free Daily 3 Check

The quota check is called after raw input is saved:

- `CaptureService.submit_capture`
- first saves via `CaptureRepository.create_capture_skeleton`
- then calls `_check_quota`

Code path:

- `backend/app/services/capture_service.py`
- `backend/app/services/usage_service.py`

### 4.2 Quota Exceeded Fallback

When `quota_decision == "quota_exceeded"`:

- the app uses localized local fallback reply
- writes `ai_reply`
- writes `model_usage_logs.fallback_used = true`
- writes `quota_decision = quota_exceeded`
- does not increment paid/high-quality usage counter

Code path:

- `backend/app/services/capture_service.py`

### 4.3 Why Quota Exceeded Cannot Block Saving

Save order:

1. `create_capture_skeleton`
2. commit `captures`
3. commit `raw_memories`
4. commit `signal_cards`
5. parser
6. quota gate
7. AI reply or fallback

Because quota gate runs after step 4, quota exceeded can only affect reply quality, not raw input persistence.

Automated test:

- `backend/tests/test_phase3_signal_cards.py::test_free_quota_exceeded_uses_fallback_without_losing_input`

---

## 5. Failure Safety Evidence

### 5.1 Parser Failure

Test:

- `backend/tests/test_phase3_signal_cards.py::test_save_first_keeps_signal_card_when_parser_and_reply_fail`

Evidence:

- `Capture` count remains 1
- `RawMemory` count remains 1
- `SignalCard` count remains 1
- `metadata_json.parser_status = failed`
- `user_confirmation = unconfirmed`

### 5.2 AI Reply Failure

Same test verifies:

- `metadata_json.ai_reply_status = fallback`
- fallback reply is saved to `SignalCard.ai_reply`
- raw input remains unchanged

### 5.3 Quota Exceeded

Test:

- `backend/tests/test_phase3_signal_cards.py::test_free_quota_exceeded_uses_fallback_without_losing_input`

Evidence:

- 4 inputs create 4 SignalCards
- first 3 are allowed
- 4th is `quota_exceeded`
- `UsageCounter.count == 3`
- raw text exists on every card

---

## 6. V3B Blocker Record

Backend unreachable is not fully complete in V3A.

Reason:

- V3A protects backend-side AI/parser/quota failure.
- True offline protection requires client-side local draft queue and retry sync.

Required V3B work:

- local draft storage before network request
- retry sync after backend returns
- duplicate-safe server upsert or client-generated id
- UI state for unsynced / synced / failed sync
- tests proving app restart does not lose unsynced drafts

Until this is done, the project must not claim full "offline / backend unreachable does not lose data" support.

---

## 7. Test Summary

Command:

```bash
cd /Users/yangyang/ai_opportunity_radar/backend
.venv/bin/pytest
```

Result:

```text
29 passed
```

Warnings:

- FastAPI `on_event` deprecation warnings.
- pytest cache write warnings from local sandbox permissions.

These warnings do not affect V3A-1 acceptance.

---

## 8. V3A-1 Archive Decision

V3A-1 can be archived as conditionally passed with one explicit blocker carried into V3B:

**Backend unreachable requires client local draft queue + retry sync before the product can claim complete no-data-loss behavior under network failure.**

