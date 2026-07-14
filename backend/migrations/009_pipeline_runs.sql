CREATE TABLE IF NOT EXISTS pipeline_runs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  pipeline_type TEXT NOT NULL,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at TIMESTAMPTZ NOT NULL,
  finished_at TIMESTAMPTZ,
  error_code TEXT,
  error_message TEXT,
  input_hash TEXT,
  output_hash TEXT,
  pipeline_version TEXT NOT NULL DEFAULT 'v4_p0_05',
  retry_count INTEGER NOT NULL DEFAULT 0,
  can_retry INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_user_source
  ON pipeline_runs(user_id, source_type, source_id, pipeline_type, status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_pipeline_runs_retry
  ON pipeline_runs(status, can_retry, updated_at DESC);

ALTER TABLE reflection_results
  ADD COLUMN IF NOT EXISTS pipeline_version TEXT NOT NULL DEFAULT 'v4_p0_05';

INSERT INTO pipeline_runs (
  id,
  user_id,
  pipeline_type,
  source_type,
  source_id,
  status,
  started_at,
  finished_at,
  input_hash,
  output_hash,
  pipeline_version,
  created_at,
  updated_at
)
SELECT
  'pipe_weekly_snapshot_' || user_id || '_' || week_start || '_v1',
  user_id,
  'weekly_aggregation',
  'weekly_snapshot',
  week_start::text,
  'completed',
  COALESCE(created_at, now()),
  COALESCE(updated_at, now()),
  NULL,
  NULL,
  'v4_p0_05',
  COALESCE(created_at, now()),
  COALESCE(updated_at, now())
FROM weekly_insights
ON CONFLICT (id) DO NOTHING;
