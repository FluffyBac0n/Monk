CREATE TABLE IF NOT EXISTS interest_preferences (
  submission_id TEXT NOT NULL,
  scope TEXT NOT NULL,
  updates_opt_in INTEGER NOT NULL DEFAULT 0 CHECK (updates_opt_in IN (0, 1)),
  platform TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL,
  PRIMARY KEY (submission_id, scope)
);
