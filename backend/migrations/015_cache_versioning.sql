ALTER TABLE reflection_results
  ADD COLUMN IF NOT EXISTS dirty INTEGER NOT NULL DEFAULT 0;

ALTER TABLE reflection_results
  ADD COLUMN IF NOT EXISTS is_stale INTEGER NOT NULL DEFAULT 0;

ALTER TABLE reflection_results
  ADD COLUMN IF NOT EXISTS stale_reason TEXT;

ALTER TABLE reflection_results
  ADD COLUMN IF NOT EXISTS invalidated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_reflection_results_cache_state
  ON reflection_results(source_type, source_id, dirty, is_stale, status);
