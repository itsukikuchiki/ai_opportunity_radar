CREATE TABLE IF NOT EXISTS experiment_candidates (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  source_week_start DATE NOT NULL,
  source_week_end DATE NOT NULL,
  title TEXT NOT NULL,
  hypothesis TEXT NOT NULL,
  suggested_action TEXT NOT NULL,
  linked_signal_card_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  linked_observation_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
  status TEXT NOT NULL DEFAULT 'generated',
  confidence_level TEXT NOT NULL DEFAULT 'medium',
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  adopted_experiment_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_experiment_candidates_source
  ON experiment_candidates(source_type, source_id, user_id);

CREATE INDEX IF NOT EXISTS idx_experiment_candidates_week
  ON experiment_candidates(user_id, source_week_start, status);

CREATE INDEX IF NOT EXISTS idx_experiment_candidates_adopted
  ON experiment_candidates(adopted_experiment_id);
