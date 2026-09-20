import { NextResponse } from 'next/server';
import { database, ensureInterestSchema } from '@/lib/db';

const interests = new Set(['volunteer', 'collaborate', 'field-walks', 'sponsor', 'host', 'other']);
const platforms = new Set(['ios', 'android', 'both', 'not-sure']);

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

function response(isHtmx: boolean, payload: { ok: boolean; duplicate?: boolean; error?: string }, status: number, kind = '', message = '', compact = false) {
  if (!isHtmx) return NextResponse.json(payload, { status });
  return new NextResponse(interestFragment(kind, message || payload.error || 'The form could not be sent.', payload.ok, compact), {
    status: 200,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'X-EuroTrex-Interest-Success': payload.ok ? 'true' : 'false',
    },
  });
}

function requestPath(request: Request) {
  const currentUrl = request.headers.get('HX-Current-URL') || request.headers.get('referer');
  if (!currentUrl) return '/';
  try {
    return new URL(currentUrl).pathname.slice(0, 240) || '/';
  } catch {
    return '/';
  }
}

export async function POST(request: Request) {
  const isHtmx = request.headers.get('HX-Request') === 'true';
  try {
    const contentType = request.headers.get('content-type') || '';
    const body = contentType.includes('application/json')
      ? await request.json() as Record<string, unknown>
      : Object.fromEntries((await request.formData()).entries());

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
    const sourcePath = field(body.sourcePath, 240) || requestPath(request);
    const consent = body.consent === true || body.consent === 'yes';

    if (!kind || !validEmail(email)) {
      const error = 'Enter a valid email address.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }
    if (kind === 'beta' && !platforms.has(platform)) {
      const error = 'Choose your preferred mobile platform.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }
    if (kind === 'involved' && (!name || !interests.has(interest) || !message || !consent)) {
      const error = 'Complete your name, interest and message, then accept the privacy notice.';
      return response(isHtmx, { ok: false, error }, 400, kind, error, compact);
    }

    await ensureInterestSchema();
    const db = database();
    const normalizedEmail = email.toLowerCase();
    const id = crypto.randomUUID();
    const createdAt = new Date().toISOString();

    if (kind === 'beta') {
      const result = await db.prepare(`
        INSERT OR IGNORE INTO interest_submissions
          (id, kind, name, email, email_normalized, organization, platform, interest, message, source_path, status, created_at)
        VALUES (?, 'beta', ?, ?, ?, '', ?, '', '', ?, 'new', ?)
      `).bind(id, '', email, normalizedEmail, platform, sourcePath, createdAt).run();
      const duplicate = result.meta.changes === 0;
      const confirmation = duplicate
        ? 'You have already asked to be notified—we’ll keep you posted.'
        : 'You’re on the notification list. We’ll email you when testing invitations or official store links are ready.';
      return response(isHtmx, { ok: true, duplicate }, duplicate ? 200 : 201, kind, confirmation, compact);
    }

    await db.prepare(`
      INSERT INTO interest_submissions
        (id, kind, name, email, email_normalized, organization, platform, interest, message, source_path, status, created_at)
      VALUES (?, 'involved', ?, ?, ?, ?, '', ?, ?, ?, 'new', ?)
    `).bind(id, name, email, normalizedEmail, organization, interest, message, sourcePath, createdAt).run();
    return response(isHtmx, { ok: true }, 201, kind, 'Thank you. Your message is with the EuroTrex team.', compact);
  } catch (error) {
    console.error('Interest submission failed', error);
    const message = 'We could not save this right now. Please try again.';
    return response(isHtmx, { ok: false, error: message }, 500, '', message);
  }
}
