import type { CyprusE4Stage } from './cyprus-e4-data';

type Fields = Record<string, unknown>;
type FirestoreValue = {
  stringValue?: string;
  integerValue?: string;
  doubleValue?: number;
  booleanValue?: boolean;
  timestampValue?: string;
  mapValue?: { fields?: Record<string, FirestoreValue> };
  arrayValue?: { values?: FirestoreValue[] };
  geoPointValue?: { latitude: number; longitude: number };
};
type Document = { name: string; fields?: Record<string, FirestoreValue> };
export type TrailPoint = {
  lat: number;
  lng: number;
  altitudeM: number | null;
  distanceKm: number | null;
};
export type PublicLodging = {
  id: string;
  name: string;
  type: string;
  stageId: string;
  stageName: string;
  village: string;
  address: string;
  priceMinEur: number | null;
  priceMaxEur: number | null;
  phone: string;
  email: string;
  website: string;
  verified: boolean;
  location: { latitude: number; longitude: number } | null;
};
export type PublicIssue = {
  id: string;
  category: string;
  description: string;
  passability: string;
  status: string;
  updatedAt: string;
};
export type PublicTrail = {
  id: string;
  name: string;
  country: string;
  distanceKm: number | null;
  highPointM: number | null;
  updatedAt: string;
  fetchedAt: string;
  stages: CyprusE4Stage[];
  lodgings: PublicLodging[];
  issues: PublicIssue[];
  points: TrailPoint[];
  lodgingsAvailable: boolean;
  issuesAvailable: boolean;
  geometryAvailable: boolean;
};

// Only unauthenticated public reads. No service credentials or private reports.
const project = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'eurotrex';
const base = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(project)}/databases/(default)/documents`;
const cache = new Map<
  string,
  { expires: number; request: Promise<PublicTrail> }
>();
let geometryCache: { revision: string; request: Promise<TrailPoint[]> } | null =
  null;
const number = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) ? value : null;
const text = (value: unknown) => (typeof value === 'string' ? value : '');
const object = (value: unknown): Fields =>
  value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Fields)
    : {};

export function decodeFirestoreValue(value: FirestoreValue): unknown {
  if ('stringValue' in value) return value.stringValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('geoPointValue' in value) return value.geoPointValue;
  if ('arrayValue' in value)
    return (value.arrayValue?.values || []).map(decodeFirestoreValue);
  if ('mapValue' in value)
    return Object.fromEntries(
      Object.entries(value.mapValue?.fields || {}).map(([key, entry]) => [
        key,
        decodeFirestoreValue(entry),
      ])
    );
  return null;
}
function fields(document: Document): Fields {
  return {
    ...Object.fromEntries(
      Object.entries(document.fields || {}).map(([key, value]) => [
        key,
        decodeFirestoreValue(value),
      ])
    ),
    id: document.name.split('/').at(-1)!,
  };
}
async function read(
  path: string,
  timeoutMs = 8000
): Promise<Record<string, unknown>> {
  const response = await fetch(`${base}/${path}`, {
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok)
    throw new Error('Public trail data could not be refreshed.');
  return response.json();
}
async function collection(path: string): Promise<Fields[]> {
  const documents: Fields[] = [];
  let token = '';
  for (let page = 0; page < 20; page++) {
    const result = await read(
      `${path}?pageSize=1000${token ? `&pageToken=${encodeURIComponent(token)}` : ''}`
    );
    for (const doc of (result.documents as Document[]) || [])
      documents.push(fields(doc));
    token = text(result.nextPageToken);
    if (!token) return documents;
  }
  throw new Error('Trail collection is too large to display completely.');
}
function location(value: unknown): PublicLodging['location'] {
  const point = object(value);
  const lat = number(point.latitude),
    lng = number(point.longitude);
  return lat !== null &&
    lng !== null &&
    Math.abs(lat) <= 90 &&
    Math.abs(lng) <= 180
    ? { latitude: lat, longitude: lng }
    : null;
}

export function decodeTrailPoints(
  metadata: Fields,
  chunks: Fields[]
): TrailPoint[] {
  const format = Array.isArray(metadata.pointFormat)
    ? metadata.pointFormat
    : ['lat', 'lng'];
  const stride = number(metadata.pointStride) ?? format.length;
  const latIndex = format.indexOf('lat'),
    lngIndex = format.indexOf('lng'),
    altitudeIndex = format.indexOf('altitudeM'),
    distanceIndex = format.indexOf('distanceKm');
  if (
    !Number.isInteger(stride) ||
    stride < 2 ||
    latIndex < 0 ||
    lngIndex < 0 ||
    Math.max(latIndex, lngIndex, altitudeIndex, distanceIndex) >= stride
  )
    throw new Error('Unsupported trail geometry.');
  const points: TrailPoint[] = [];
  for (const chunk of [...chunks].sort(
    (a, b) => (number(a.chunkIndex) || 0) - (number(b.chunkIndex) || 0)
  )) {
    const values = chunk.points;
    if (!Array.isArray(values) || values.length % stride)
      throw new Error('Incomplete trail geometry.');
    for (let index = 0; index < values.length; index += stride) {
      const lat = number(values[index + latIndex]),
        lng = number(values[index + lngIndex]);
      if (
        lat === null ||
        lng === null ||
        Math.abs(lat) > 90 ||
        Math.abs(lng) > 180
      )
        throw new Error('Invalid trail point.');
      points.push({
        lat,
        lng,
        altitudeM:
          altitudeIndex < 0 ? null : number(values[index + altitudeIndex]),
        distanceKm:
          distanceIndex < 0 ? null : number(values[index + distanceIndex]),
      });
    }
  }
  if (
    points.length < 2 ||
    (number(metadata.pointCount) !== null &&
      points.length !== number(metadata.pointCount)) ||
    (number(metadata.chunkCount) !== null &&
      chunks.length !== number(metadata.chunkCount))
  )
    throw new Error('Incomplete trail geometry.');
  return points;
}

async function fetchTrail(id: string): Promise<PublicTrail> {
  const prefix = `trails/${id}`;
  const root = await read(prefix).then(value => fields(value as Document));
  const releasePrefix = root.publishedReleaseId ? `${prefix}/releases/${encodeURIComponent(text(root.publishedReleaseId))}` : prefix;
  const [stageRows, metadata, lodgingRows, issueRows] = await Promise.all(
    [
      collection(`${releasePrefix}/stages`),
      read(`${releasePrefix}/routeMetadata/main`)
        .then((value) => fields(value as Document))
        .catch(() => null),
      collection(`${prefix}/lodgings`).catch(() => null),
      collection('trailIssues').catch(() => null),
    ]
  );
  const stages: CyprusE4Stage[] = stageRows
    .map((stage) => ({
      id: text(stage.id),
      sequence: number(stage.sequence) ?? 0,
      name: text(stage.name),
      distanceFromPathKm: number(stage.distanceFromPathKm),
      accumulatedDistanceKm: number(stage.accumulatedDistanceKm),
      segmentLengthKm: number(stage.segmentLengthKm),
      elevationUpM: number(stage.elevationUpM),
      elevationDownM: number(stage.elevationDownM),
      altitudeM: number(stage.altitudeM),
      services: Object.fromEntries(
        Object.entries(object(stage.services)).filter(
          ([, value]) => typeof value === 'boolean'
        )
      ) as Record<string, boolean>,
      location: location(stage.location),
    }))
    .sort(
      (a, b) =>
        (a.accumulatedDistanceKm ?? Infinity) -
        (b.accumulatedDistanceKm ?? Infinity)
    );
  if (
    stages.length < 2 ||
    stages.some((stage) => stage.accumulatedDistanceKm === null)
  )
    throw new Error('Trail reference points are incomplete.');
  const lodgings = (lodgingRows || [])
    .map((row) => {
      const contact = object(row.contact);
      const rawPhone = text(row.phone) || text(contact.phone);
      const localPhone = rawPhone.replace(/[\s()-]/g, '');
      return {
        id: text(row.id),
        name: text(row.name),
        type: text(row.type),
        stageId: text(row.stageId),
        stageName: text(row.stageName),
        village: text(row.village),
        address: text(row.address),
        priceMinEur: number(row.priceMinEur),
        priceMaxEur: number(row.priceMaxEur),
        phone:
          root.country === 'Cyprus' && /^\d{8}$/.test(localPhone)
            ? `+357${localPhone}`
            : rawPhone,
        email: text(row.email) || text(contact.email),
        website: text(row.website) || text(contact.website),
        verified: Boolean(
          text(row.approvedAt) &&
            Number.isFinite(Date.parse(text(row.approvedAt)))
        ),
        location: location(row.location),
      };
    })
    .sort(
      (a, b) =>
        Number(Boolean(b.name)) - Number(Boolean(a.name)) ||
        a.name.localeCompare(b.name)
    );
  const issues = (issueRows || [])
    .filter(
      (row) =>
        row.trailId === id &&
        ['reviewed', 'forwarded'].includes(text(row.status))
    )
    .map((row) => ({
      id: text(row.id),
      category: text(row.category),
      description: text(row.description),
      passability: text(row.passability),
      status: text(row.status),
      updatedAt: text(row.updatedAt),
    }))
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  let points: TrailPoint[] = [];
  if (metadata) {
    try {
      const revision = JSON.stringify([
        project,
        id,
        root.publishedReleaseId,
        metadata.version,
        metadata.updatedAt,
        metadata.pointCount,
        metadata.chunkCount,
      ]);
      if (geometryCache?.revision !== revision) {
        const request = collection(`${releasePrefix}/routeChunks`).then((chunks) =>
          decodeTrailPoints(metadata, chunks)
        );
        geometryCache = { revision, request };
      }
      points = await geometryCache.request;
    } catch {
      geometryCache = null;
      /* Explicit geometry-unavailable state in the guide. */
    }
  }
  return {
    id,
    name: text(root.name),
    country: text(root.country),
    distanceKm: number(root.totalDistanceKm),
    highPointM: number(metadata?.maxAltitudeM),
    updatedAt: text(root.updatedAt),
    fetchedAt: new Date().toISOString(),
    stages,
    lodgings,
    issues,
    points,
    lodgingsAvailable: lodgingRows !== null,
    issuesAvailable: issueRows !== null,
    geometryAvailable: points.length > 1,
  };
}

export async function getPublicTrail(): Promise<PublicTrail> {
  const id = 'cyprus-e4';
  const current = cache.get(id);
  if (current && current.expires > Date.now()) return current.request;
  const request = fetchTrail(id)
    .then((trail) => {
      if (
        !trail.geometryAvailable ||
        !trail.issuesAvailable ||
        !trail.lodgingsAvailable
      )
        cache.delete(id);
      return trail;
    })
    .catch((error) => {
      cache.delete(id);
      throw error;
    });
  cache.set(id, { expires: Date.now() + 60000, request });
  return request;
}

export function safePublicUrl(
  value: string,
  scheme: 'http' | 'email' | 'phone' = 'http'
) {
  if (scheme === 'email')
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? `mailto:${value}` : null;
  if (scheme === 'phone') {
    const clean = value.replace(/[\s()-]/g, '');
    return /^\+?\d{6,16}$/.test(clean) ? `tel:${clean}` : null;
  }
  try {
    const url = new URL(value);
    return ['https:', 'http:'].includes(url.protocol) &&
      !url.username &&
      !url.password
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

export type PublicTrailOverview = {
  distanceKm: number | null;
  referencePoints: number | null;
  highPointM: number | null;
};
let overviewCache: {
  expires: number;
  request: Promise<PublicTrailOverview>;
} | null = null;

// The homepage needs two public metadata documents, not route geometry or listings.
export async function getPublicTrailOverview(): Promise<PublicTrailOverview> {
  if (overviewCache && overviewCache.expires > Date.now())
    return overviewCache.request;
  const request = read('trails/cyprus-e4', 2500).then(value => fields(value as Document))
    .then(async root => {
      const prefix = root.publishedReleaseId ? `trails/cyprus-e4/releases/${encodeURIComponent(text(root.publishedReleaseId))}` : 'trails/cyprus-e4';
      const metadata = await read(`${prefix}/routeMetadata/main`, 2500).then(value => fields(value as Document)).catch(() => null);
      return {distanceKm: number(root.totalDistanceKm), referencePoints: number(root.stageCount), highPointM: number(metadata?.maxAltitudeM)};
    })
    .catch((error) => {
      overviewCache = null;
      throw error;
    });
  overviewCache = { expires: Date.now() + 60000, request };
  return request;
}
