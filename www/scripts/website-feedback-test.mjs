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
const { buildElevationProfile, contourColor, axisTicks } = moduleAt(
  '../lib/elevation-profile.ts'
);
const elevationPoints = [0, 0, 0, 700, 0, 0, 0].map(
  (altitudeM, distanceKm) => ({ altitudeM, distanceKm, lat: 0, lng: 0 })
);
const elevationProfile = buildElevationProfile(elevationPoints, 6);
assert.equal(
  elevationProfile.segments[0][3].altitudeM,
  100,
  'The mobile seven-point average smooths a single spike before rendering'
);
assert.equal(
  elevationProfile.segments[0][0].altitudeM,
  175,
  'Windows truncate at the route endpoints'
);
assert.equal(
  elevationPoints[3].altitudeM,
  700,
  'Display smoothing leaves recorded route measurements intact'
);
assert.equal(contourColor(0), '#3e9ed0');
assert.equal(contourColor(300), '#61af57');
assert.equal(contourColor(700), '#d8aa35');
assert.equal(contourColor(2200), '#d66b35');
assert.equal(
  contourColor(150),
  '#50a794',
  'Altitude colours interpolate between the mobile contour anchors'
);
assert.deepEqual(axisTicks(0, 558, 5), [0, 200, 400, 558]);
assert.equal(buildElevationProfile([], null), null);
const withGap = buildElevationProfile(
  [
    ...elevationPoints,
    { ...elevationPoints[0], altitudeM: null, distanceKm: 7 },
    ...elevationPoints.map((p) => ({ ...p, distanceKm: p.distanceKm + 8 })),
  ],
  14
);
assert.equal(
  withGap.segments.length,
  2,
  'Missing measurements leave a visible break in the profile'
);
const longElevation = buildElevationProfile(
  Array.from({ length: 10000 }, (_, i) => ({
    lat: 0,
    lng: 0,
    altitudeM: i,
    distanceKm: i / 10,
  })),
  null
);
assert.ok(longElevation.segments[0].length <= 901);
assert.equal(
  longElevation.segments[0].at(-1).distanceKm,
  999.9,
  'Downsampling retains the route endpoint'
);
const { encodedMapPath, trailMapImageUrl, trailMapCamera } = moduleAt(
  '../lib/trail-map-image.ts'
);
const mapFixture = [
  [38.5, -120.2],
  [40.7, -120.95],
  [43.252, -126.453],
].map(([lat, lng]) => ({ lat, lng }));
assert.equal(
  encodedMapPath(mapFixture),
  '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
  'Precision-5 path encoding matches the standard fixture'
);
assert.throws(() => trailMapImageUrl([], 'pk.synthetic'), /unavailable/);
const longRoute = Array.from({ length: 24000 }, (_, i) => ({
  lat: 34.5 + i / 24000,
  lng: 32 + Math.sin(i / 50),
}));
const imageUrl = trailMapImageUrl(longRoute, 'pk.synthetic');
assert.ok(imageUrl.length <= 8000);
assert.equal(new URL(imageUrl).hostname, 'api.mapbox.com');
assert.ok(
  !imageUrl.includes('pin-s-'),
  'Lettered endpoint pins are replaced by the app flags'
);
const camera = trailMapCamera(longRoute);
assert.ok(
  imageUrl.includes(`/${camera.lng},${camera.lat},${camera.zoom},0,0/1200x700`)
);
for (const endpoint of [camera.start, camera.finish]) {
  assert.ok(
    endpoint.x >= 44 &&
      endpoint.x <= 1156 &&
      endpoint.y >= 44 &&
      endpoint.y <= 656,
    'Endpoint flags remain inside the padded map viewport'
  );
}
const symmetric = trailMapCamera([
  { lat: 0, lng: -1 },
  { lat: 0, lng: 1 },
]);
assert.ok(Math.abs(symmetric.start.y - 350) < 0.001);
assert.ok(
  Math.abs(symmetric.start.x + symmetric.finish.x - 1200) < 0.001,
  'A shared Mercator camera aligns endpoints symmetrically around the centre'
);
const coincident = trailMapCamera([
  { lat: 35, lng: 33 },
  { lat: 35, lng: 33 },
]);
assert.ok(Number.isFinite(coincident.zoom));
assert.ok(Math.abs(coincident.start.x - 600) < 0.001);
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

const overviewReads = [];
const overviewSource = moduleAt(
  '../lib/public-trail-data.ts',
  {},
  {
    fetch: async (url) => {
      overviewReads.push(String(url));
      const metadata = String(url).includes('/routeMetadata/');
      return new Response(
        JSON.stringify({
          name: 'trails/cyprus-e4',
          fields: metadata
            ? { maxAltitudeM: { doubleValue: 1872.4 } }
            : {
                totalDistanceKm: { doubleValue: 432.1 },
                stageCount: { integerValue: '87' },
              },
        })
      );
    },
  }
);
const [overviewA, overviewB] = await Promise.all([
  overviewSource.getPublicTrailOverview(),
  overviewSource.getPublicTrailOverview(),
]);
assert.deepEqual(overviewA, {
  distanceKm: 432.1,
  referencePoints: 87,
  highPointM: 1872.4,
});
assert.deepEqual(overviewB, overviewA);
assert.equal(
  overviewReads.length,
  2,
  'Concurrent homepage requests share two lightweight metadata reads'
);
assert.ok(
  overviewReads.every((url) => !/routeChunks|lodgings|trailIssues/.test(url))
);
const partialOverview = moduleAt(
  '../lib/public-trail-data.ts',
  {},
  {
    fetch: async (url) =>
      String(url).includes('/routeMetadata/')
        ? new Response('{}', { status: 503 })
        : new Response(
            JSON.stringify({
              name: 'trails/cyprus-e4',
              fields: { totalDistanceKm: { doubleValue: 0 } },
            })
          ),
  }
);
assert.deepEqual(
  await partialOverview.getPublicTrailOverview(),
  { distanceKm: 0, referencePoints: null, highPointM: null },
  'Unavailable metrics stay absent without invented fallback statistics'
);

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
