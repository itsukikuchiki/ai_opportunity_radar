create table if not exists signal_processing_state (
  signal_id text primary key references signal_cards(id) on delete cascade,
  sync_status text not null default 'synced',
  assist_status text not null default 'not_started',
  reason_status text not null default 'not_started',
  daily_status text not null default 'not_started',
  weekly_status text not null default 'not_started',
  journey_status text not null default 'not_started',
  last_processed_at timestamptz,
  retry_count integer not null default 0,
  processing_version text not null default 'v4_p0_02',
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists ix_signal_processing_state_sync_status
  on signal_processing_state(sync_status);

create index if not exists ix_signal_processing_state_stages
  on signal_processing_state(daily_status, weekly_status, journey_status);

create table if not exists signal_analysis_policy (
  signal_id text primary key references signal_cards(id) on delete cascade,
  privacy_level text not null default 'private',
  is_sensitive boolean not null default false,
  is_excluded boolean not null default false,
  do_not_analyze boolean not null default false,
  requires_user_confirmation boolean not null default false,
  confirmed_by_user boolean not null default false,
  inaccurate boolean not null default false,
  exclusion_reason text,
  updated_at timestamptz not null default now()
);

create index if not exists ix_signal_analysis_policy_privacy
  on signal_analysis_policy(privacy_level);

create index if not exists ix_signal_analysis_policy_flags
  on signal_analysis_policy(inaccurate, do_not_analyze, is_sensitive, is_excluded);

insert into signal_processing_state (
  signal_id,
  sync_status,
  daily_status,
  weekly_status,
  journey_status,
  created_at,
  updated_at
)
select
  id,
  'synced',
  case when included_in_summary then 'included' else 'not_started' end,
  case when included_in_weekly then 'included' else 'not_started' end,
  case when included_in_journey then 'included' else 'not_started' end,
  now(),
  coalesce(updated_at, now())
from signal_cards
on conflict (signal_id) do nothing;

insert into signal_analysis_policy (
  signal_id,
  privacy_level,
  is_sensitive,
  is_excluded,
  do_not_analyze,
  confirmed_by_user,
  inaccurate,
  exclusion_reason,
  updated_at
)
select
  id,
  privacy_level,
  privacy_level = 'sensitive',
  privacy_level = 'excluded',
  privacy_level = 'do_not_analyze',
  user_confirmation in ('confirmed', 'edited', 'supplemented'),
  user_confirmation = 'inaccurate',
  case
    when user_confirmation = 'inaccurate' then 'inaccurate'
    when privacy_level in ('sensitive', 'excluded', 'do_not_analyze') then privacy_level
    else null
  end,
  coalesce(updated_at, now())
from signal_cards
on conflict (signal_id) do nothing;
