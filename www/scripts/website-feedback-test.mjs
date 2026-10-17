import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import ts from 'typescript';

function moduleAt(file, imports = {}, globals = {}) {
  const code = ts.transpileModule(
    readFileSync(new URL(file, import.meta.url), 'utf8'),
    {
      compilerOptions: {
        module: ts.ModuleKind.CommonJS,
        target: ts.ScriptTarget.ES2022,
      },
    }
  ).outputText;
  const exports = {};
  new Function('exports', 'require', ...Object.keys(globals), code)(
    exports,
    (name) => {
      if (name in imports) return imports[name];
      throw new Error(`Unexpected module ${name}`);
    },
    ...Object.values(globals)
  );
  return exports;
}
const { buildItinerary } = moduleAt('../lib/web-itinerary.ts');
const stages = [0, 10, 20, 30, 40].map((km, index) => ({
  id: `point-${index}`,
  name: `Point ${index}`,
  sequence: 5 - index,
  accumulatedDistanceKm: km,
  segmentLengthKm: index ? 10 : 0,
  elevationUpM: index * 100,
  elevationDownM: index * 10,
  altitudeM: km,
  location: null,
  services: {
    lodging: false,
    tent: index === 1 || index === 3,
    drinkableWater: index === 2,
  },
}));
const stays = [{ id: 'stay', stageId: 'point-2', name: 'Recorded stay' }];
const options = { start: 'point-0', end: 'point-4', maxKm: 25, camping: false };
const plan = buildItinerary(stages, stays, options);
assert.equal(plan.days.length, 2);
assert.equal(plan.distanceKm, 40);
assert.equal(plan.days[0].end.id, 'point-2');
assert.deepEqual(
  plan.days.map((day) => day.distanceKm),
  [20, 20]
);
assert.equal(plan.days[0].ascentM, 300);
assert.equal(plan.days[0].descentM, 30);
assert.equal(plan.days[1].ascentM, 700);
assert.equal(plan.days[1].descentM, 70);
assert.ok(buildItinerary(stages, stays, { ...options, days: 1 }).error);
assert.ok(buildItinerary(stages, stays, { ...options, days: 3 }).error);
assert.ok(
  buildItinerary(stages, [], options).error,
  'do not invent overnight stays'
);
assert.equal(
  buildItinerary(stages, [], { ...options, camping: true, maxKm: 20 }).days
    .length,
  3
);
assert.ok(buildItinerary(stages, stays, { ...options, maxKm: 9 }).error);
assert.ok(buildItinerary(stages, stays, { ...options, maxKm: NaN }).error);
assert.ok(
  buildItinerary(stages, stays, { ...options, start: 'missing' }).error
);
assert.ok(buildItinerary(stages, stays, { ...options, end: 'point-0' }).error);
const reverse = buildItinerary(stages, stays, {
  ...options,
  start: 'point-4',
  end: 'point-0',
});
assert.deepEqual(
  reverse.days.map((day) => day.distanceKm),
  [20, 20]
);
assert.equal(reverse.days[0].ascentM, 70);
assert.equal(reverse.days[0].descentM, 700);
assert.equal(reverse.days[1].ascentM, 30);
assert.equal(reverse.days[1].descentM, 300);
const missing = stages.map((point, index) => ({
  ...point,
  elevationUpM: index === 1 ? null : point.elevationUpM,
}));
assert.equal(
  buildItinerary(missing, stays, options).days[0].ascentM,
  null,
  'missing ascent is not zero'
);
const { decodeTrailPoints, decodeFirestoreValue, safePublicUrl } = moduleAt(
  '../lib/public-trail-data.ts'
);
const meta = {
  pointFormat: ['lat', 'lng', 'altitudeM', 'distanceKm', 'reverseDistanceKm'],
  pointStride: 5,
  pointCount: 2,
  chunkCount: 2,
};
const chunks = [
  { chunkIndex: 1, points: [35, 33, 150, 10, 0] },
  { chunkIndex: 0, points: [34, 32, 0, 0, 10] },
];
assert.deepEqual(decodeTrailPoints(meta, chunks), [
  { lat: 34, lng: 32, altitudeM: 0, distanceKm: 0 },
  { lat: 35, lng: 33, altitudeM: 150, distanceKm: 10 },
]);
assert.throws(
  () => decodeTrailPoints({ ...meta, pointCount: 3 }, chunks),
  /Incomplete/
);
assert.throws(() => decodeTrailPoints(meta, [chunks[0]]), /Incomplete/);
assert.throws(
  () =>
    decodeTrailPoints(meta, [
      chunks[0],
      { chunkIndex: 0, points: [100, 32, 0, 0, 10] },
    ]),
  /Invalid/
);
assert.throws(
  () => decodeTrailPoints({ ...meta, pointStride: 0 }, chunks),
  /Unsupported/
);
assert.deepEqual(
  decodeFirestoreValue({
    mapValue: {
      fields: {
        count: { integerValue: '123' },
        enabled: { booleanValue: false },
        zero: { doubleValue: 0 },
      },
    },
  }),
  { count: 123, enabled: false, zero: 0 }
);
assert.equal(safePublicUrl('javascript:alert(1)'), null);
assert.equal(safePublicUrl('https://user:password@example.com'), null);
assert.equal(
  safePublicUrl('https://example.com/stay'),
  'https://example.com/stay'
);
assert.equal(safePublicUrl('+357 99123456', 'phone'), 'tel:+35799123456');

const project = 'demo-test';
const { publicNoticeHtml } = moduleAt('../lib/public-notices.ts');
const notice = publicNoticeHtml(
  [
    {
      id: 'approved',
      category: '<script>category</script>',
      description: '<img src=x onerror=alert(1)>',
      passability: 'unsure',
      status: 'reviewed',
      updatedAt: '2026-10-17',
      privateEmail: 'private@example.test',
    },
  ],
  true
);
assert.ok(!notice.includes('<script>'));
assert.ok(!notice.includes('<img'));
assert.ok(notice.includes('&lt;img'));
assert.ok(!notice.includes('private@example.test'));
assert.match(publicNoticeHtml([], true), /does not confirm/);
assert.match(publicNoticeHtml([], false), /could not be refreshed/);
const token = (claims) =>
  `header.${Buffer.from(JSON.stringify({ sub: 'reviewer', aud: project, iss: `https://securetoken.google.com/${project}`, ...claims })).toString('base64url')}.signature`;
const request = (value) =>
  new Request('http://localhost/api/stories', {
    headers: value ? { Authorization: `Bearer ${value}` } : {},
  });
function authCase({
  verified = true,
  disabled = false,
  membership = 200,
  lookup = 200,
  claims = {},
} = {}) {
  const calls = [];
  const source = moduleAt(
    '../lib/story-admin.ts',
    {
      './firebase-config': {
        firebaseConfig: { apiKey: 'test-key', projectId: project },
      },
    },
    {
      fetch: async (url, options) => {
        calls.push({ url, options });
        return String(url).includes('accounts:lookup')
          ? new Response(
              JSON.stringify({
                users: [
                  { localId: 'reviewer', emailVerified: verified, disabled },
                ],
              }),
              { status: lookup }
            )
          : new Response('{}', { status: membership });
      },
      process: { env: { NODE_ENV: 'test' } },
    }
  );
  return {
    calls,
    run: () => source.requireStoryAdmin(request(token(claims))),
    source,
  };
}
assert.equal(await authCase().run(), 'reviewer');
await assert.rejects(
  authCase({ verified: false }).run(),
  /verified administrator/
);
await assert.rejects(
  authCase({ disabled: true }).run(),
  /verified administrator/
);
await assert.rejects(
  authCase({ membership: 404 }).run(),
  /administrator access/
);
assert.equal(
  await authCase({ membership: 404, claims: { admin: true } }).run(),
  'reviewer'
);
await assert.rejects(
  authCase({ membership: 403, claims: { admin: true } }).run(),
  /administrator access/
);
await assert.rejects(authCase({ lookup: 400 }).run(), /session/);
await assert.rejects(
  authCase({ claims: { aud: 'another-project' } }).run(),
  /different project/
);
const missingToken = authCase();
await assert.rejects(
  missingToken.source.requireStoryAdmin(request()),
  /Sign in/
);
assert.equal(missingToken.calls.length, 0);
console.log(
  'PASS: balanced and reverse itineraries; overnight/camping constraints; impossible plans; missing metrics; live route decoding; complete geometry; safe contact URLs; verified administrator access, role checks and cross-project token rejection.'
);
