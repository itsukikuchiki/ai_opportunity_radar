create table analytics_events (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  event_name text not null,
  event_date date not null,
  properties_json jsonb not null default '{}'::jsonb,
  numeric_value double precision,
  created_at timestamptz not null default now()
);

create index ix_analytics_events_user_id on analytics_events(user_id);
create index ix_analytics_events_event_name on analytics_events(event_name);
create index ix_analytics_events_event_date on analytics_events(event_date);
create index ix_analytics_events_created_at on analytics_events(created_at);

create table user_subscriptions (
  user_id text primary key references users(id) on delete cascade,
  product_id text,
  status text not null default 'inactive',
  environment text,
  reason text,
  transaction_date text,
  latest_verified_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ix_user_subscriptions_product_id on user_subscriptions(product_id);

create table ai_usage (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  endpoint text not null,
  estimated_input_tokens integer not null default 0,
  estimated_output_tokens integer not null default 0,
  estimated_cost_usd double precision not null default 0,
  created_at timestamptz not null default now()
);

create index ix_ai_usage_user_id on ai_usage(user_id);
create index ix_ai_usage_endpoint on ai_usage(endpoint);
create index ix_ai_usage_created_at on ai_usage(created_at);
