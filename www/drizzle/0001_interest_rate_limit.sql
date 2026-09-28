CREATE TABLE IF NOT EXISTS interest_rate_limits (
  bucket_key TEXT PRIMARY KEY NOT NULL,
  request_count INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS interest_rate_limits_expiry_idx
ON interest_rate_limits (expires_at);
