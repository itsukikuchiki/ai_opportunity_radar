CREATE TABLE IF NOT EXISTS trace_links (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL,
  source_id TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  relation_type TEXT NOT NULL,
  weight DOUBLE PRECISION NOT NULL DEFAULT 1.0,
  status TEXT NOT NULL DEFAULT 'active',
  metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_trace_links_source_target_relation UNIQUE (
    source_type,
    source_id,
    target_type,
    target_id,
    relation_type
  )
);

CREATE INDEX IF NOT EXISTS idx_trace_links_source
  ON trace_links(source_type, source_id, relation_type, status);

CREATE INDEX IF NOT EXISTS idx_trace_links_target
  ON trace_links(target_type, target_id, relation_type, status);

CREATE INDEX IF NOT EXISTS idx_trace_links_user_status
  ON trace_links(user_id, status, updated_at DESC);
