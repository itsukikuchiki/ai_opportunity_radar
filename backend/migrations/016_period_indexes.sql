CREATE INDEX IF NOT EXISTS ix_signal_cards_user_period_weekly
  ON signal_cards(user_id, local_date, included_in_weekly, created_at);

CREATE INDEX IF NOT EXISTS ix_signal_cards_user_period_journey
  ON signal_cards(user_id, local_date, included_in_journey, created_at);

CREATE INDEX IF NOT EXISTS idx_life_experiment_rollups_user_period
  ON life_experiment_rollups(user_id, source_week_start, source_week_end, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_life_experiment_events_user_period
  ON life_experiment_lifecycle_events(user_id, local_date, event_type);

CREATE INDEX IF NOT EXISTS idx_reflection_results_user_source_state
  ON reflection_results(user_id, source_type, source_id, dirty, is_stale, generated_at DESC);
