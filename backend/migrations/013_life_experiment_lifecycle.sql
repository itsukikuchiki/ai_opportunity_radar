CREATE TABLE IF NOT EXISTS life_experiment_lifecycle_events (
  id TEXT PRIMARY KEY,
  experiment_id TEXT NOT NULL,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  event_date TIMESTAMPTZ NOT NULL,
  local_date DATE NOT NULL,
  source_type TEXT,
  source_id TEXT,
  status_from TEXT,
  status_to TEXT,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_life_experiment_events_exp
  ON life_experiment_lifecycle_events(experiment_id, event_date DESC);

CREATE INDEX IF NOT EXISTS idx_life_experiment_events_user_date
  ON life_experiment_lifecycle_events(user_id, local_date DESC);

CREATE TABLE IF NOT EXISTS life_experiment_rollups (
  experiment_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  root_experiment_id TEXT NOT NULL,
  parent_experiment_id TEXT,
  source_week_start DATE NOT NULL,
  source_week_end DATE NOT NULL,
  current_status TEXT NOT NULL,
  title TEXT NOT NULL,
  hypothesis TEXT NOT NULL,
  suggested_action TEXT NOT NULL,
  total_feedback_count INTEGER NOT NULL DEFAULT 0,
  tried_count INTEGER NOT NULL DEFAULT 0,
  helpful_count INTEGER NOT NULL DEFAULT 0,
  not_helpful_count INTEGER NOT NULL DEFAULT 0,
  adjusted_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  active_week_count INTEGER NOT NULL DEFAULT 1,
  first_started_at TIMESTAMPTZ,
  last_feedback_at TIMESTAMPTZ,
  last_event_at TIMESTAMPTZ,
  lineage JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_user_week
  ON life_experiment_rollups(user_id, source_week_start DESC);

CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_root
  ON life_experiment_rollups(root_experiment_id, source_week_start DESC);
