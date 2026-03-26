create table users (
  id text primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table user_profiles (
  user_id text primary key references users(id) on delete cascade,
  selected_repeat_area text,
  selected_ai_help_type text,
  selected_output_preference text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
