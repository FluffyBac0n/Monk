import type { TrailPoint } from './public-trail-data';

type Sample = { distanceKm: number; altitudeM: number };
export const contourAnchors = [
  { altitude: 0, color: '#3e9ed0' },
  { altitude: 300, color: '#61af57' },
  { altitude: 700, color: '#d8aa35' },
  { altitude: 1200, color: '#d66b35' },
];

export function contourColor(altitude: number) {
  if (altitude <= 0) return contourAnchors[0].color;
  for (let i = 1; i < contourAnchors.length; i++) {
    const low = contourAnchors[i - 1],
      high = contourAnchors[i];
    if (altitude > high.altitude) continue;
    const fraction = (altitude - low.altitude) / (high.altitude - low.altitude);
    const channel = (color: string, offset: number) =>
      parseInt(color.slice(offset, offset + 2), 16);
    return (
      '#' +
      [1, 3, 5]
        .map((offset) =>
          Math.round(
            channel(low.color, offset) +
              fraction *
                (channel(high.color, offset) - channel(low.color, offset))
          )
            .toString(16)
            .padStart(2, '0')
        )
        .join('')
    );
  }
  return contourAnchors.at(-1)!.color;
}

export function axisTicks(min: number, max: number, divisions: number) {
  const raw = (max - min) / divisions;
  if (!(raw > 0)) return [min];
  const magnitude = 10 ** Math.floor(Math.log10(raw));
  const normalized = raw / magnitude;
  const step =
    (normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10) *
    magnitude;
  const ticks = [min];
  for (let value = Math.ceil(min / step) * step; value < max; value += step) {
    if (value > min && value - ticks.at(-1)! >= step * 0.35) ticks.push(value);
  }
  if (max - ticks.at(-1)! >= step * 0.35) ticks.push(max);
  return ticks;
}

export function buildElevationProfile(
  points: TrailPoint[],
  recordedDistance: number | null
) {
  // Missing measurements break the line rather than inventing a connection.
  const segments: Sample[][] = [];
  let current: Sample[] = [];
  for (const point of points) {
    if (
      point.altitudeM === null ||
      point.distanceKm === null ||
      !Number.isFinite(point.altitudeM) ||
      !Number.isFinite(point.distanceKm) ||
      point.distanceKm < 0
    ) {
      if (current.length) segments.push(current);
      current = [];
      continue;
    }
    if (current.length && point.distanceKm < current.at(-1)!.distanceKm) {
      segments.push(current);
      current = [];
    }
    current.push({ altitudeM: point.altitudeM, distanceKm: point.distanceKm });
  }
  if (current.length) segments.push(current);
  // The app averages a seven-point window before sampling for display.
  const smoothed = segments.map((segment) => {
    if (segment.length < 3) return segment;
    const prefix = [0];
    for (const point of segment) prefix.push(prefix.at(-1)! + point.altitudeM);
    return segment.map((point, index) => {
      const start = Math.max(0, index - 3),
        end = Math.min(segment.length, index + 4);
      return {
        ...point,
        altitudeM: (prefix[end] - prefix[start]) / (end - start),
      };
    });
  });
  const samples = smoothed.flat();
  if (samples.length < 2) return null;
  const min = Math.floor(Math.min(0, ...samples.map((p) => p.altitudeM)));
  const max = Math.max(
    min + 100,
    Math.ceil(Math.max(...samples.map((p) => p.altitudeM)) / 100) * 100
  );
  const distance = Math.max(
    recordedDistance ?? 0,
    ...samples.map((p) => p.distanceKm)
  );
  if (!(distance > 0)) return null;
  const stride = Math.max(1, Math.ceil(samples.length / 900));
  const displaySegments = smoothed
    .filter((segment) => segment.length > 1)
    .map((segment) =>
      segment.filter(
        (_, index) => index % stride === 0 || index === segment.length - 1
      )
    );
  if (!displaySegments.length) return null;
  const gradient = [
    min,
    ...contourAnchors.map((a) => a.altitude).filter((a) => a > min && a < max),
    max,
  ].map((altitude) => ({
    offset: (altitude - min) / (max - min),
    color: contourColor(altitude),
  }));
  return {
    segments: displaySegments,
    min,
    max,
    distance,
    gradient,
    xTicks: axisTicks(0, distance, 5),
    yTicks: axisTicks(min, max, 4),
  };
}
