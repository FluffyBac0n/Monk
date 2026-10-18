// Local-only integration checks. Uses synthetic data and removes only its own rows.
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readdirSync } from 'node:fs';
import { resolve } from 'node:path';

const origin = 'http://localhost:3000';
const state = resolve('.wrangler/state/v3/d1/miniflare-D1DatabaseObject');
const file = readdirSync(state).find(
  (name) => name.endsWith('.sqlite') && name !== 'metadata.sqlite'
);
assert.ok(file, 'Local D1 must exist');
const db = new DatabaseSync(resolve(state, file));
const email = `experience-${crypto.randomUUID()}@example.test`;

async function post(body, options = {}) {
  const response = await fetch(
    `${origin}/api/interest?kind=${options.kind || 'involved'}`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Origin: options.origin || origin,
        ...options.headers,
      },
      body: JSON.stringify(body),
    }
  );
  return { status: response.status, text: await response.text() };
}

try {
  for (const path of [
    '/',
    '/about',
    '/get-inspired',
    '/become-a-host',
    '/help',
    '/get-involved',
    '/partnerships',
    '/trails/cyprus-e4',
    '/trails/cyprus-e4/stages',
    '/trails/cyprus-e4/stages/123-pafos-airport',
    '/trails/crete-e4',
    '/trails/peloponnese-e4',
  ]) {
    const response = await fetch(origin + path);
    assert.equal(response.status, 200, path);
    const text = await response.text();
    assert.ok(text.includes('<main'), `${path} includes page content`);
  }
  const initialGuide = await (await fetch(`${origin}/trails/cyprus-e4`)).text();
  assert.ok(
    !initialGuide.includes('class="public-stay"'),
    'Accommodation results stay absent before search'
  );
  assert.ok(
    !initialGuide.includes('Showing 1–'),
    'No result count is shown before search'
  );
  const searchedGuide = await (
    await fetch(`${origin}/trails/cyprus-e4?findStays=yes&stay=777`)
  ).text();
  assert.ok(
    searchedGuide.includes('class="public-stay"'),
    'Submitting a search renders accommodation cards'
  );
  assert.ok(searchedGuide.includes('777 Beach Guesthouse'));
  const emptyGuide = await (
    await fetch(
      `${origin}/trails/cyprus-e4?findStays=yes&stay=synthetic-no-matching-stay`
    )
  ).text();
  assert.ok(emptyGuide.includes('No stays match your search.'));
  assert.ok(!emptyGuide.includes('class="public-stay"'));
  const enquiry = {
    name: 'Local QA',
    email,
    interest: 'report',
    message: 'Synthetic local smoke test. No reply needed.',
  };
  assert.equal(
    (await post(enquiry)).status,
    201,
    'Enquiry succeeds without marketing consent'
  );
  assert.equal((await post({ ...enquiry, consent: 'yes' })).status, 201);
  const preferences = db
    .prepare(
      'SELECT p.updates_opt_in FROM interest_preferences p JOIN interest_submissions s ON p.submission_id=s.id WHERE s.email_normalized=? AND s.kind=? ORDER BY p.updates_opt_in'
    )
    .all(email, 'involved');
  assert.deepEqual(
    preferences.map((row) => row.updates_opt_in),
    [0, 1]
  );
  for (const trail of ['crete-e4', 'peloponnese-e4', 'crete-e4']) {
    assert.equal(
      (await post({ email, platform: 'android', trail }, { kind: 'beta' }))
        .status,
      200
    );
  }
  assert.equal(
    db
      .prepare(
        "SELECT COUNT(*) AS n FROM interest_submissions WHERE email_normalized=? AND kind='beta'"
      )
      .get(email).n,
    1
  );
  assert.equal(
    db
      .prepare(
        "SELECT COUNT(*) AS n FROM interest_preferences p JOIN interest_submissions s ON p.submission_id=s.id WHERE s.email_normalized=? AND s.kind='beta'"
      )
      .get(email).n,
    2
  );
  assert.equal(
    (await post({ email, platform: 'ios', trail: 'unknown' }, { kind: 'beta' }))
      .status,
    400
  );
  assert.equal(
    (await post({ email, platform: 'invalid' }, { kind: 'beta' })).status,
    400
  );
  const emailOnly = await fetch(
    `${origin}/api/interest?kind=beta&compact=true`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Origin: origin,
        'HX-Request': 'true',
      },
      body: new URLSearchParams({ email, trail: 'all' }),
    }
  );
  assert.equal(
    emailOnly.headers.get('X-EuroTrex-Interest-Success'),
    'true',
    'Email-only HTMX signup succeeds'
  );
  assert.ok(
    (await emailOnly.text()).includes('You’re on the notification list')
  );
  assert.equal(
    db
      .prepare(
        "SELECT p.platform FROM interest_preferences p JOIN interest_submissions s ON p.submission_id=s.id WHERE s.email_normalized=? AND p.scope='all'"
      )
      .get(email).platform,
    'not-sure'
  );
  assert.equal(
    db
      .prepare(
        "SELECT COUNT(*) AS n FROM interest_submissions WHERE email_normalized=? AND kind='beta'"
      )
      .get(email).n,
    1,
    'Email-only signup is deduplicated'
  );
  assert.equal(
    (await post({ email: 'invalid' }, { kind: 'beta' })).status,
    400
  );
  assert.equal((await post({ ...enquiry, email: 'invalid' })).status, 400);
  assert.equal(
    (await post(enquiry, { origin: 'https://unrelated.example' })).status,
    403
  );
  const htmx = await post(
    { ...enquiry, email: 'invalid' },
    { headers: { 'HX-Request': 'true' } }
  );
  assert.equal(htmx.status, 200);
  assert.ok(htmx.text.includes('role="alert"'));
  const report = await (
    await fetch(
      `${origin}/get-involved?interest=report&point=123-pafos-airport`
    )
  ).text();
  assert.ok(report.includes('Stage point: Pafos Airport'));
  const notices = await fetch(`${origin}/api/trail-notices`);
  assert.equal(notices.status, 200);
  assert.match(notices.headers.get('content-type'), /text\/html/);
  assert.ok(
    !(await notices.text()).includes('<main'),
    'notice polling replaces only its feed'
  );
  for (const interest of [
    'partner-host',
    'premium-host',
    'friend-of-the-path',
    'member',
    'donate',
    'work',
  ])
    assert.equal((await post({ ...enquiry, interest })).status, 201, interest);
  const story = {
    ...enquiry,
    interest: 'story',
    publicName: 'Local trail author',
    storyTitle: 'Synthetic local story',
    message: 'A synthetic story. <script>window.bad=true</script>',
  };
  assert.equal(
    (await post(story)).status,
    400,
    'publication permission is required'
  );
  assert.equal(
    (await post({ ...story, publicationConsent: 'yes' })).status,
    201
  );
  const record = db
    .prepare(
      "SELECT s.id,s.status,p.public_name,p.publication_consent,p.title FROM interest_submissions s JOIN story_publication_permissions p ON p.submission_id=s.id WHERE s.email_normalized=? AND s.interest='story'"
    )
    .get(email);
  assert.equal(record.status, 'new');
  assert.equal(record.publication_consent, 1);
  let inspiration = await (await fetch(`${origin}/get-inspired`)).text();
  assert.ok(
    !inspiration.includes(story.storyTitle),
    'pending stories are never public'
  );
  assert.equal(
    (await fetch(`${origin}/api/stories`)).status,
    401,
    'anonymous readers cannot access story moderation'
  );
  assert.equal(
    (
      await fetch(`${origin}/api/stories`, {
        method: 'POST',
        headers: { Origin: origin, 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: record.id, action: 'approve' }),
      })
    ).status,
    401
  );
  assert.equal(
    (
      await fetch(`${origin}/api/stories`, {
        method: 'POST',
        headers: {
          Origin: 'https://unrelated.example',
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ id: record.id, action: 'approve' }),
      })
    ).status,
    403
  );
  // A trusted local fixture simulates moderation without touching production accounts.
  db.prepare(
    "UPDATE interest_submissions SET status='approved' WHERE id=?"
  ).run(record.id);
  db.prepare(
    'UPDATE story_publication_permissions SET reviewed_at=? WHERE submission_id=?'
  ).run(new Date().toISOString(), record.id);
  inspiration = await (await fetch(`${origin}/get-inspired`)).text();
  assert.ok(inspiration.includes(story.storyTitle));
  assert.ok(inspiration.includes('Local trail author'));
  assert.ok(
    !inspiration.includes(email),
    'private enquiry email is excluded from publication'
  );
  assert.ok(
    !inspiration.includes('<script>window.bad=true</script>'),
    'story markup is escaped'
  );
  db.prepare(
    "UPDATE interest_submissions SET status='rejected' WHERE id=?"
  ).run(record.id);
  assert.ok(
    !(await (await fetch(`${origin}/get-inspired`)).text()).includes(
      story.storyTitle
    ),
    'removal unpublishes stories'
  );
  console.log(
    'PASS: 12 routes; report context; consent persistence; notification scope/deduplication; programme enquiries; story submission, approval/removal, private-email exclusion and escaped markup; anonymous moderation denial; same-origin protection and HTMX errors.'
  );
} finally {
  db.prepare(
    'DELETE FROM story_publication_permissions WHERE submission_id IN (SELECT id FROM interest_submissions WHERE email_normalized=?)'
  ).run(email);
  db.prepare(
    'DELETE FROM interest_preferences WHERE submission_id IN (SELECT id FROM interest_submissions WHERE email_normalized=?)'
  ).run(email);
  db.prepare('DELETE FROM interest_submissions WHERE email_normalized=?').run(
    email
  );
  db.close();
}
