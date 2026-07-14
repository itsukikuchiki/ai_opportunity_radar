ALTER TABLE signal_cards
  ADD COLUMN IF NOT EXISTS client_id TEXT;

ALTER TABLE signal_cards
  ADD COLUMN IF NOT EXISTS server_id TEXT;

UPDATE signal_cards
SET
  client_id = COALESCE(client_id, id),
  server_id = COALESCE(server_id, id)
WHERE client_id IS NULL OR server_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_signal_cards_user_client_id
  ON signal_cards(user_id, client_id)
  WHERE client_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_signal_cards_server_id
  ON signal_cards(server_id);
