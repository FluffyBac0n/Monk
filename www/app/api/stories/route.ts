import { NextResponse } from 'next/server';
import { database, ensureInterestSchema } from '@/lib/db';
import { requireStoryAdmin, StoryAccessError } from '@/lib/story-admin';

function failure(error: unknown) {
  return NextResponse.json(
    {
      error:
        error instanceof StoryAccessError
          ? error.message
          : 'The story queue could not be updated. Please try again.',
    },
    {
      status: error instanceof StoryAccessError ? error.status : 503,
      headers: { 'Cache-Control': 'no-store' },
    }
  );
}

export async function GET(request: Request) {
  try {
    await requireStoryAdmin(request);
    await ensureInterestSchema();
    const result = await database()
      .prepare(
        `SELECT s.id,s.message AS body,s.status,s.created_at AS createdAt,p.public_name AS publicName,p.title,p.consent_at AS consentAt
      FROM interest_submissions s JOIN story_publication_permissions p ON p.submission_id=s.id
      WHERE s.interest='story' AND s.kind='involved' AND p.publication_consent=1
      ORDER BY CASE WHEN s.status='new' THEN 0 ELSE 1 END,s.created_at DESC LIMIT 100`
      )
      .all();
    return NextResponse.json(
      { stories: result.results },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    return failure(error);
  }
}

export async function POST(request: Request) {
  try {
    if (request.headers.get('origin') !== new URL(request.url).origin)
      throw new StoryAccessError(
        403,
        'Review stories from the Eurotrex website.'
      );
    const reviewer = await requireStoryAdmin(request);
    if (!request.headers.get('content-type')?.startsWith('application/json'))
      throw new StoryAccessError(415, 'Use the story review controls.');
    const reader = request.body?.getReader();
    let body = '';
    let length = 0;
    if (!reader) throw new StoryAccessError(400, 'Choose a story to review.');
    const decoder = new TextDecoder();
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) break;
      length += chunk.value.byteLength;
      if (length > 2000) {
        await reader.cancel();
        throw new StoryAccessError(413, 'The review request is too large.');
      }
      body += decoder.decode(chunk.value, { stream: true });
    }
    let parsed: { id?: unknown; action?: unknown };
    try {
      parsed = JSON.parse(body);
    } catch {
      throw new StoryAccessError(400, 'The review request could not be read.');
    }
    if (
      !parsed ||
      typeof parsed.id !== 'string' ||
      !/^[0-9a-f-]{36}$/.test(parsed.id) ||
      !['approve', 'reject'].includes(String(parsed.action))
    )
      throw new StoryAccessError(
        400,
        'Choose a valid story and review action.'
      );
    await ensureInterestSchema();
    const db = database();
    const status = parsed.action === 'approve' ? 'approved' : 'rejected';
    const results = await db.batch([
      db
        .prepare(
          "UPDATE interest_submissions SET status=? WHERE id=? AND kind='involved' AND interest='story' AND id IN (SELECT submission_id FROM story_publication_permissions WHERE publication_consent=1)"
        )
        .bind(status, parsed.id),
      db
        .prepare(
          'UPDATE story_publication_permissions SET reviewed_by=?,reviewed_at=? WHERE submission_id=? AND publication_consent=1'
        )
        .bind(reviewer, new Date().toISOString(), parsed.id),
    ]);
    if (!results[0].meta.changes)
      throw new StoryAccessError(
        404,
        'This story is no longer available for review.'
      );
    return NextResponse.json(
      { ok: true, status },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  } catch (error) {
    return failure(error);
  }
}
