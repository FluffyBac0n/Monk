import { env } from 'cloudflare:workers';
import { NextResponse } from 'next/server';
import { database, ensureInterestSchema } from '@/lib/db';

const interests = new Set(['volunteer', 'collaborate', 'field-walks', 'sponsor', 'host', 'other', 'report']);
const trailScopes = new Set(['all', 'cyprus-e4', 'crete-e4', 'peloponnese-e4']);
const platforms = new Set(['ios', 'android', 'both', 'not-sure']);
const acceptedMediaTypes = new Set(['application/json', 'application/x-www-form-urlencoded']);
const maximumBodyBytes = 16 * 1024;
const rateLimitWindowSeconds = 10 * 60;
const rateLimitRequests = 8;

class RequestError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

function field(value: unknown, maximum: number) {
  return typeof value === 'string' ? value.trim().slice(0, maximum) : '';
}

function validEmail(email: string) {
  return email.length <= 254 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function interestFragment(kind: string, message: string, success: boolean, compact = false) {
  if (!success) return `<p class="form-message error" role="alert">${message}</p>`;
  const title = kind === 'beta' ? 'You’re on the trail.' : 'Message received.';
  return `<div class="interest-success${compact ? ' compact' : ''}" role="status" tabindex="-1"><span aria-hidden="true">✓</span><div><strong>${title}</strong><p>${message}</p></div></div>`;
}

function response(
  isHtmx: boolean,
  payload: { ok: boolean; error?: string },
  status: number,
  kind = '',
  message = '',
  compact = false,
) {
  const headers = { 'Cache-Control': 'no-store', Vary: 'HX-Request' };
  if (!isHtmx) return NextResponse.json(payload, { status, headers });
  return new NextResponse(interestFragment(kind, message || payload.error || 'The form could not be sent.', payload.ok, compact), {
    status: 200,
    headers: {
      ...headers,
      'content-type': 'text/html; charset=utf-8',
      'X-EuroTrex-Interest-Success': payload.ok ? 'true' : 'false',
      'X-EuroTrex-Interest-Status': String(status),
    },
  });
}

function assertSameOrigin(request: Request) {
  const expectedOrigin = new URL(request.url).origin;
  const origin = request.headers.get('origin');
  if (origin) {
    if (origin !== expectedOrigin) throw new RequestError(403, 'This form can only be submitted from the EuroTrex website.');
    return;
  }

  const referer = request.headers.get('referer');
  if (!referer) throw new RequestError(403, 'This form can only be submitted from the EuroTrex website.');
  try {
    if (new URL(referer).origin !== expectedOrigin) throw new Error();
  } catch {
    throw new RequestError(403, 'This form can only be submitted from the EuroTrex website.');
  }
}

async function boundedBody(request: Request) {
  const declaredLength = Number(request.headers.get('content-length') || 0);
  if (Number.isFinite(declaredLength) && declaredLength > maximumBodyBytes) {
    throw new RequestError(413, 'This submission is too large.');
  }
  if (!request.body) return '';

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maximumBodyBytes) {
      await reader.cancel();
      throw new RequestError(413, 'This submission is too large.');
    }
    chunks.push(value);
  }

  const combined = new Uint8Array(total);
  let offset = 0;
  chunks.forEach((chunk) => { combined.set(chunk, offset); offset += chunk.byteLength; });
  return new TextDecoder().decode(combined);
}

async function requestBody(request: Request) {
  const mediaType = (request.headers.get('content-type') || '').split(';', 1)[0].trim().toLowerCase();
  if (!acceptedMediaTypes.has(mediaType)) throw new RequestError(415, 'Use the website form to send this request.');
  const text = await boundedBody(request);

  try {
    if (mediaType === 'application/json') {
      const parsed: unknown = JSON.parse(text);
      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) throw new Error();
      return parsed as Record<string, unknown>;
    }
    return Object.fromEntries(new URLSearchParams(text).entries());
  } catch {
    throw new RequestError(400, 'The form data could not be read.');
  }
}

function requestPath(request: Request) {
  const currentUrl = request.headers.get('HX-Current-URL') || request.headers.get('referer');
  if (!currentUrl) return '/';
  try {
    const parsed = new URL(currentUrl, request.url);
    if (parsed.origin !== new URL(request.url).origin) return '/';
    return parsed.pathname.slice(0, 240) || '/';
  } catch {
    return '/';
  }
}

async function hmac(value: string, secret: string) {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = await crypto.subtle.sign('HMAC', key, encoder.encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

async function rateLimited(request: Request) {
  const secret = env.INTEREST_RATE_LIMIT_SECRET;
  const address = request.headers.get('CF-Connecting-IP');
  if (!secret || !address) return false;

  const db = database();
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + rateLimitWindowSeconds;
  const bucket = await hmac(address, secret);
  await db.prepare('DELETE FROM interest_rate_limits WHERE expires_at <= ?').bind(now).run();
  const result = await db.prepare(`
    INSERT INTO interest_rate_limits (bucket_key, request_count, expires_at)
    VALUES (?, 1, ?)
    ON CONFLICT(bucket_key) DO UPDATE SET
      request_count = CASE WHEN interest_rate_limits.expires_at <= ? THEN 1 ELSE interest_rate_limits.request_count + 1 END,
      expires_at = CASE WHEN interest_rate_limits.expires_at <= ? THEN excluded.expires_at ELSE interest_rate_limits.expires_at END
    RETURNING request_count
  `).bind(bucket, expiresAt, now, now).first<{ request_count: number }>();
  return Number(result?.request_count || 0) > rateLimitRequests;
}

export async function POST(request: Request) {
  const isHtmx = request.headers.get('HX-Request') === 'true';
  try {
    assertSameOrigin(request);
    const body = await requestBody(request);
    await ensureInterestSchema();
    if (await rateLimited(request)) {
      const message = 'Too many requests were received. Please wait a few minutes and try again.';
      return response(isHtmx, { ok: false, error: message }, 429, '', message);
    }

    const searchParams = new URL(request.url).searchParams;
    const requestedKind = body.kind || searchParams.get('kind');
    const kind = requestedKind === 'beta' || requestedKind === 'involved' ? requestedKind : '';
    const compact = body.compact === true || body.compact === 'true' || searchParams.get('compact') === 'true';
    if (field(body.website, 200)) return response(isHtmx, { ok: true }, 200, kind, 'Thank you.', compact);

    const email = field(body.email, 254);
    const name = field(body.name, 120);
    const organization = field(body.organization, 160);
    const platform = field(body.platform, 20);
    const interest = field(body.interest, 30);
    const message = field(body.message, 1500);
    const sourcePath = requestPath(request);
    const consent = body.consent === true || body.consent === 'yes';
    const trail = field(body.trail, 40) || 'all';

    if (!kind || !validEmail(email)) {
      const error = 'Enter a valid email address.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }
    if (kind === 'beta' && (!platforms.has(platform) || !trailScopes.has(trail))) {
      const error = 'Choose your preferred mobile platform.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }
    if (kind === 'involved' && (!name || !interests.has(interest) || !message)) {
      const error = 'Complete your name, interest and message.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }

    const db = database();
    const normalizedEmail = email.toLowerCase();
    const id = crypto.randomUUID();
    const createdAt = new Date().toISOString();

    if (kind === 'beta') {
      await db.batch([db.prepare(`
        INSERT OR IGNORE INTO interest_submissions
          (id, kind, name, email, email_normalized, organization, platform, interest, message, source_path, status, created_at)
        VALUES (?, 'beta', ?, ?, ?, '', ?, '', '', ?, 'new', ?)
      `).bind(id, '', email, normalizedEmail, platform, sourcePath, createdAt),
      db.prepare(`INSERT INTO interest_preferences (submission_id, scope, updates_opt_in, platform, updated_at)
        SELECT id, ?, 1, ?, ? FROM interest_submissions WHERE kind = 'beta' AND email_normalized = ?
        ON CONFLICT(submission_id, scope) DO UPDATE SET platform = excluded.platform, updated_at = excluded.updated_at, updates_opt_in = 1
      `).bind(trail, platform, createdAt, normalizedEmail)]);
      const confirmation = trail === 'all' ? 'You’re on the notification list. We’ll email you when testing invitations or official store links are ready.' : 'Your trail preference is saved. We’ll email you when there is news about this guide or its availability in the app.';
      return response(isHtmx, { ok: true }, 200, kind, confirmation, compact);
    }

    await db.batch([db.prepare(`
      INSERT INTO interest_submissions
        (id, kind, name, email, email_normalized, organization, platform, interest, message, source_path, status, created_at)
      VALUES (?, 'involved', ?, ?, ?, ?, '', ?, ?, ?, 'new', ?)
    `).bind(id, name, email, normalizedEmail, organization, interest, message, sourcePath, createdAt),
    db.prepare('INSERT INTO interest_preferences (submission_id, scope, updates_opt_in, platform, updated_at) VALUES (?, ?, ?, ?, ?)').bind(id, 'project', consent ? 1 : 0, '', createdAt)]);
    return response(isHtmx, { ok: true }, 201, kind, 'Thank you. Your message is with the EuroTrex team.', compact);
  } catch (caught) {
    if (caught instanceof RequestError) {
      return response(isHtmx, { ok: false, error: caught.message }, caught.status, '', caught.message);
    }
    console.error('Interest submission failed', caught);
    const message = 'We could not save this right now. Please try again.';
    return response(isHtmx, { ok: false, error: message }, 500, '', message);
  }
}
