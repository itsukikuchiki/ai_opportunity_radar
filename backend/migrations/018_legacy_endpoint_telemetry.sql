CREATE TABLE IF NOT EXISTS legacy_endpoint_telemetry (
    id TEXT PRIMARY KEY,
    counter_name TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    client_version TEXT,
    platform TEXT,
    user_id_hash TEXT,
    account_id_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_legacy_endpoint_counter
    ON legacy_endpoint_telemetry(counter_name, created_at);

CREATE INDEX IF NOT EXISTS idx_legacy_endpoint_endpoint
    ON legacy_endpoint_telemetry(endpoint, created_at);

CREATE INDEX IF NOT EXISTS idx_legacy_endpoint_user_hash
    ON legacy_endpoint_telemetry(user_id_hash);

CREATE INDEX IF NOT EXISTS idx_legacy_endpoint_account_hash
    ON legacy_endpoint_telemetry(account_id_hash);
