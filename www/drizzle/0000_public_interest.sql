CREATE TABLE IF NOT EXISTS interest_submissions (
  id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('beta', 'involved')),
  name TEXT NOT NULL DEFAULT '',
  email TEXT NOT NULL,
  email_normalized TEXT NOT NULL,
  organization TEXT NOT NULL DEFAULT '',
  platform TEXT NOT NULL DEFAULT '',
  interest TEXT NOT NULL DEFAULT '',
  message TEXT NOT NULL DEFAULT '',
  source_path TEXT NOT NULL DEFAULT '/',
  status TEXT NOT NULL DEFAULT 'new',
  created_at TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS interest_submissions_beta_email_idx
ON interest_submissions (email_normalized)
WHERE kind = 'beta';

CREATE INDEX IF NOT EXISTS interest_submissions_created_at_idx
ON interest_submissions (created_at DESC);
