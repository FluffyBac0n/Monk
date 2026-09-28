export const interestSubmissionsTable = `
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
  )
`;

export const betaEmailIndex = `
  CREATE UNIQUE INDEX IF NOT EXISTS interest_submissions_beta_email_idx
  ON interest_submissions (email_normalized)
  WHERE kind = 'beta'
`;

export const interestCreatedAtIndex = `
  CREATE INDEX IF NOT EXISTS interest_submissions_created_at_idx
  ON interest_submissions (created_at DESC)
`;

export const interestRateLimitsTable = `
  CREATE TABLE IF NOT EXISTS interest_rate_limits (
    bucket_key TEXT PRIMARY KEY NOT NULL,
    request_count INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
  )
`;

export const interestRateLimitExpiryIndex = `
  CREATE INDEX IF NOT EXISTS interest_rate_limits_expiry_idx
  ON interest_rate_limits (expires_at)
`;
