create table signal_cards (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  capture_id text references captures(id) on delete set null,
  raw_memory_id text references raw_memories(id) on delete set null,
  source_type text not null,
  raw_text text not null default '',
  raw_payload_json jsonb not null default '{}'::jsonb,
  ai_reply text,
  created_at timestamptz not null,
  local_date date not null,
  timezone text not null default 'UTC',
  language text not null default 'en',
  emotion text,
  intensity integer,
  scene text,
  friction text,
  positive_signal text,
  energy_load text,
  linked_life_chain_stage jsonb not null default '{}'::jsonb,
  confidence_score double precision,
  user_confirmation text not null default 'unconfirmed',
  user_correction_json jsonb not null default '{}'::jsonb,
  included_in_summary boolean not null default false,
  included_in_weekly boolean not null default false,
  included_in_journey boolean not null default false,
  linked_experiment_id text,
  parser_version text not null default 'v3_rules_1',
  model_used text,
  prompt_version text,
  token_usage_json jsonb not null default '{}'::jsonb,
  privacy_level text not null default 'private',
  schema_version integer not null default 1,
  is_legacy boolean not null default false,
  migration_status text not null default 'native',
  metadata_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index ix_signal_cards_user_id on signal_cards(user_id);
create index ix_signal_cards_capture_id on signal_cards(capture_id);
create index ix_signal_cards_raw_memory_id on signal_cards(raw_memory_id);
create index ix_signal_cards_source_type on signal_cards(source_type);
create index ix_signal_cards_created_at on signal_cards(created_at);
create index ix_signal_cards_local_date on signal_cards(local_date);
create index ix_signal_cards_linked_experiment_id on signal_cards(linked_experiment_id);

create table usage_counters (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  feature_key text not null,
  period_type text not null,
  period_start text not null,
  count integer not null default 0,
  token_input integer not null default 0,
  token_output integer not null default 0,
  token_cached_input integer not null default 0,
  model_used text,
  source_event_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ix_usage_counters_user_id on usage_counters(user_id);
create index ix_usage_counters_feature_key on usage_counters(feature_key);
create index ix_usage_counters_period_type on usage_counters(period_type);
create index ix_usage_counters_period_start on usage_counters(period_start);
create index ix_usage_counters_source_event_id on usage_counters(source_event_id);

create table model_usage_logs (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  feature_key text not null,
  model_used text,
  parser_version text,
  prompt_version text,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  cached_input_tokens integer not null default 0,
  latency_ms integer,
  fallback_used boolean not null default false,
  quota_decision text not null default 'allowed',
  cache_hit boolean not null default false,
  source_event_id text,
  metadata_json jsonb not null default '{}'::jsonb,
  estimated_cost_usd double precision not null default 0,
  created_at timestamptz not null default now()
);

create index ix_model_usage_logs_user_id on model_usage_logs(user_id);
create index ix_model_usage_logs_feature_key on model_usage_logs(feature_key);
create index ix_model_usage_logs_model_used on model_usage_logs(model_used);
create index ix_model_usage_logs_source_event_id on model_usage_logs(source_event_id);
create index ix_model_usage_logs_created_at on model_usage_logs(created_at);

create table quota_gate_events (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  feature_key text not null,
  entitlement text not null default 'free',
  period_type text not null,
  period_start text not null,
  limit_value integer,
  used_value integer not null default 0,
  decision text not null,
  source_event_id text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index ix_quota_gate_events_user_id on quota_gate_events(user_id);
create index ix_quota_gate_events_feature_key on quota_gate_events(feature_key);
create index ix_quota_gate_events_decision on quota_gate_events(decision);
create index ix_quota_gate_events_source_event_id on quota_gate_events(source_event_id);
create index ix_quota_gate_events_created_at on quota_gate_events(created_at);
