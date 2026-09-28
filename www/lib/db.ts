import { env } from 'cloudflare:workers';
import {
  betaEmailIndex,
  interestCreatedAtIndex,
  interestRateLimitExpiryIndex,
  interestRateLimitsTable,
  interestSubmissionsTable,
} from '@/db/schema';

let schemaReady: Promise<void> | null = null;

export function database() {
  const db = env.DB as D1Database | undefined;
  if (!db) throw new Error('The site database is not configured.');
  return db;
}

export async function ensureInterestSchema() {
  if (!schemaReady) {
    const db = database();
    schemaReady = db
      .batch([
        db.prepare(interestSubmissionsTable),
        db.prepare(betaEmailIndex),
        db.prepare(interestCreatedAtIndex),
        db.prepare(interestRateLimitsTable),
        db.prepare(interestRateLimitExpiryIndex),
      ])
      .then(() => undefined)
      .catch((error) => {
        schemaReady = null;
        throw error;
      });
  }
  await schemaReady;
}
