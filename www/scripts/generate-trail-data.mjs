import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const sourcePath = resolve(process.cwd(), '../outputs/import-preview.json');
const targetPath = resolve(process.cwd(), 'lib/cyprus-e4-data.ts');
const source = JSON.parse(await readFile(sourcePath, 'utf8'));

const stages = source.stages.map((stage) => ({
  id: stage.id,
  sequence: stage.sequence,
  name: stage.name,
  distanceFromPathKm: stage.distanceFromPathKm,
  accumulatedDistanceKm: stage.accumulatedDistanceKm,
  segmentLengthKm: stage.segmentLengthKm,
  elevationUpM: stage.elevationUpM,
  elevationDownM: stage.elevationDownM,
  altitudeM: stage.altitudeM,
  services: stage.services,
  location: source.routeMarkers.find((marker) => marker.stageId === stage.id)?.location ?? null,
}));

const payload = `// Generated from outputs/import-preview.json by scripts/generate-trail-data.mjs.
// The source snapshot passed validation on 14 August 2026.

export type CyprusE4Stage = {
  id: string;
  sequence: number;
  name: string;
  distanceFromPathKm: number | null;
  accumulatedDistanceKm: number | null;
  segmentLengthKm: number | null;
  elevationUpM: number | null;
  elevationDownM: number | null;
  altitudeM: number | null;
  services: Record<string, boolean>;
  location: { latitude: number; longitude: number } | null;
};

export const cyprusE4 = ${JSON.stringify({
  id: source.trail.id,
  name: 'Cyprus-E4',
  country: source.trail.country,
  distanceKm: source.trail.totalDistanceKm,
  stageCount: source.trail.stageCount,
  highPointM: source.routeMetadata.maxAltitudeM,
  startStageName: source.trail.startStageName,
  endStageName: source.trail.endStageName,
  dataUpdatedAt: '2026-08-07T13:15:48Z',
}, null, 2)} as const;

export const cyprusE4Stages: CyprusE4Stage[] = ${JSON.stringify(stages, null, 2)};

export const recordedStays = ${JSON.stringify(source.lodgings.map((stay) => ({
  id: stay.id, stageId: stay.stageId, name: stay.name, type: stay.type, village: stay.village,
  priceMinEur: stay.priceMinEur, priceMaxEur: stay.priceMaxEur,
  distanceFromTrailKm: stay.distanceFromTrailKm,
  website: stay.contact?.website ?? null, mapUrl: stay.contact?.googleMapsUrl ?? null,
})), null, 2)};

export const routeLocator = ${JSON.stringify((() => {
  const points = source.routeChunks.flatMap((chunk) => {
    const rows = [];
    for (let i = 0; i < chunk.points.length; i += source.routeMetadata.pointStride * 12) {
      rows.push([chunk.points[i], chunk.points[i + 1]]);
    }
    return rows;
  });
  const { minLat, maxLat, minLng, maxLng } = source.routeMetadata.bounds;
  const project = (lat, lng) => [30 + (lng - minLng) / (maxLng - minLng) * 540, 190 - (lat - minLat) / (maxLat - minLat) * 160];
  return { bounds: source.routeMetadata.bounds, path: points.map(([lat, lng], i) => `${i ? 'L' : 'M'}${project(lat, lng).map((v) => v.toFixed(1)).join(',')}`).join(' ') };
})())};

export function getCyprusE4Stage(id: string) {
  return cyprusE4Stages.find((stage) => stage.id === id);
}
`;

await writeFile(targetPath, payload);
console.log(`Generated ${targetPath} with ${stages.length} stage points.`);
