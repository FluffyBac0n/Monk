declare namespace Cloudflare {
  interface Env {
    DB: D1Database;
    INTEREST_RATE_LIMIT_SECRET?: string;
  }
}
