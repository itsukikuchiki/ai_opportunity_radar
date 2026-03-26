create table patterns (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  name text not null,
  description text,
  scene_type text,
  frequency_7d integer not null default 0,
  frequency_30d integer not null default 0,
  stability_score numeric(4,3) not null default 0,
  confidence_score numeric(4,3) not null default 0,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  status text not null default 'candidate',
  summary_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table frictions (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  name text not null,
  friction_type text not null,
  description text,
  severity_score numeric(4,3) not null default 0,
  frequency_7d integer not null default 0,
  frequency_30d integer not null default 0,
  confidence_score numeric(4,3) not null default 0,
  related_pattern_ids jsonb not null default '[]'::jsonb,
  representative_quotes jsonb not null default '[]'::jsonb,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  status text not null default 'candidate',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table desires (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  name text not null,
  description text,
  mention_count integer not null default 0,
  priority_score numeric(4,3) not null default 0,
  related_pattern_ids jsonb not null default '[]'::jsonb,
  related_friction_ids jsonb not null default '[]'::jsonb,
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
