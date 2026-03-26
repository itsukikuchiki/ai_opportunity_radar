create table captures (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  content text not null,
  input_mode text not null,
  tag_hint text,
  created_at timestamptz not null default now()
);

create table raw_memories (
  id text primary key,
  user_id text not null references users(id) on delete cascade,
  capture_id text references captures(id) on delete set null,
  source text not null,
  content text not null,
  signal_type text,
  scene_type text,
  friction_type text,
  emotion_strength text,
  repetition_flag boolean not null default false,
  desire_flag boolean not null default false,
  related_pattern_id text,
  related_friction_id text,
  metadata_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
