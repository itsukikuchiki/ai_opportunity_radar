CREATE TABLE IF NOT EXISTS observations (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  observation_text TEXT NOT NULL,
  observation_type TEXT NOT NULL DEFAULT 'hypothesis',
  confidence TEXT NOT NULL DEFAULT 'medium',
  status TEXT NOT NULL DEFAULT 'generated',
  source_period_start DATE,
  source_period_end DATE,
  created_by TEXT NOT NULL DEFAULT 'l2_reason',
  source_ai_judgement_id TEXT,
  evidence_text TEXT,
  suggested_pattern TEXT,
  suggested_life_chain_stage TEXT,
  user_adjustment_text TEXT,
  confirmation_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  dismissed_at TIMESTAMPTZ,
  archived_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_observations_user_status_date
  ON observations(user_id, status, source_period_start, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_observations_ai_judgement
  ON observations(source_ai_judgement_id);

CREATE TABLE IF NOT EXISTS observation_signal_links (
  observation_id TEXT NOT NULL REFERENCES observations(id) ON DELETE CASCADE,
  signal_id TEXT NOT NULL REFERENCES signal_cards(id) ON DELETE CASCADE,
  weight DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (observation_id, signal_id)
);

CREATE INDEX IF NOT EXISTS idx_observation_signal_links_signal
  ON observation_signal_links(signal_id);
