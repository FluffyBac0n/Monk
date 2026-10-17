CREATE TABLE IF NOT EXISTS story_publication_permissions (
  submission_id TEXT PRIMARY KEY NOT NULL,
  public_name TEXT NOT NULL,
  title TEXT NOT NULL,
  publication_consent INTEGER NOT NULL CHECK (publication_consent IN (0, 1)),
  consent_at TEXT NOT NULL,
  reviewed_by TEXT NOT NULL DEFAULT '',
  reviewed_at TEXT NOT NULL DEFAULT ''
);
