CREATE TABLE IF NOT EXISTS candidate_groups (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  candidate_kind TEXT NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  source_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'ready',
  required_signal_count INTEGER NOT NULL DEFAULT 3,
  eligible_signal_count INTEGER NOT NULL DEFAULT 0,
  dirty BOOLEAN NOT NULL DEFAULT false,
  is_stale BOOLEAN NOT NULL DEFAULT false,
  stale_reason TEXT,
  invalidated_at TIMESTAMPTZ,
  generation_started_at TIMESTAMPTZ,
  generation_finished_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, candidate_kind, period_start, source_hash)
);

CREATE INDEX IF NOT EXISTS idx_candidate_groups_read
  ON candidate_groups(user_id, candidate_kind, period_start, status, updated_at DESC);

CREATE TABLE IF NOT EXISTS micro_action_candidates (
  id TEXT PRIMARY KEY,
  candidate_group_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  local_date DATE NOT NULL,
  rank INTEGER NOT NULL CHECK (rank BETWEEN 1 AND 3),
  title TEXT NOT NULL,
  reason TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'very_light',
  linked_signal_card_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  focus_domain_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'generated',
  adopted_micro_action_id TEXT,
  source_hash TEXT NOT NULL,
  dirty BOOLEAN NOT NULL DEFAULT false,
  is_stale BOOLEAN NOT NULL DEFAULT false,
  stale_reason TEXT,
  invalidated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_micro_action_candidates_group
  ON micro_action_candidates(candidate_group_id, rank);

CREATE INDEX IF NOT EXISTS idx_micro_action_candidates_read
  ON micro_action_candidates(user_id, local_date, status, dirty, is_stale, rank);

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS candidate_group_id TEXT;

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS candidate_rank INTEGER NOT NULL DEFAULT 1;

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS source_hash TEXT;

CREATE INDEX IF NOT EXISTS idx_experiment_candidates_group
  ON experiment_candidates(candidate_group_id, candidate_rank);
