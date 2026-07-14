CREATE TABLE IF NOT EXISTS reflection_results (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  reflection_type TEXT NOT NULL,
  ai_level TEXT NOT NULL,
  content_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'generated',
  schema_version INTEGER NOT NULL DEFAULT 1,
  prompt_version TEXT,
  model_version TEXT,
  source_hash TEXT,
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  superseded_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reflection_results_user_source
  ON reflection_results(user_id, source_type, source_id, reflection_type, status, generated_at DESC);

INSERT INTO reflection_results (
  id,
  user_id,
  source_type,
  source_id,
  reflection_type,
  ai_level,
  content_json,
  status,
  schema_version,
  generated_at,
  created_at,
  updated_at
)
SELECT
  'refl_weekly_snapshot_' || user_id || '_' || week_start || '_reflect_v1',
  user_id,
  'weekly_snapshot',
  week_start::text,
  'reflect',
  'L3',
  jsonb_build_object(
    'key_insight', key_insight,
    'patterns', top_patterns_json,
    'frictions', top_frictions_json,
    'best_action', best_action,
    'opportunity_snapshot', opportunity_snapshot_json
  ),
  'generated',
  1,
  COALESCE(updated_at, now()),
  COALESCE(created_at, now()),
  COALESCE(updated_at, now())
FROM weekly_insights
ON CONFLICT (id) DO NOTHING;
