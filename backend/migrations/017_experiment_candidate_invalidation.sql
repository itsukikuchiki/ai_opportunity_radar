ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS dirty BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS is_stale BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS stale_reason TEXT;

ALTER TABLE experiment_candidates
  ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_experiment_candidates_stale
  ON experiment_candidates(user_id, source_week_start, dirty, is_stale, status);
