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
};

export const cyprusE4 = ${JSON.stringify({
  id: source.trail.id,
  name: source.trail.name,
  country: source.trail.country,
  distanceKm: source.trail.totalDistanceKm,
  stageCount: source.trail.stageCount,
  highPointM: source.routeMetadata.maxAltitudeM,
  startStageName: source.trail.startStageName,
  endStageName: source.trail.endStageName,
  dataUpdatedAt: '2026-08-07T13:15:48Z',
}, null, 2)} as const;

export const cyprusE4Stages: CyprusE4Stage[] = ${JSON.stringify(stages, null, 2)};

export function getCyprusE4Stage(id: string) {
  return cyprusE4Stages.find((stage) => stage.id === id);
}
`;

await writeFile(targetPath, payload);
console.log(`Generated ${targetPath} with ${stages.length} stage points.`);
