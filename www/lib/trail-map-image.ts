import type { TrailPoint } from './public-trail-data';

// One explicit Mercator camera keeps HTML flag markers aligned with the image.
export function trailMapCamera(points: TrailPoint[]) {
  if (points.length < 2) throw new Error('The recorded route is unavailable.');
  const project = (point: Pick<TrailPoint, 'lat' | 'lng'>) => {
    const latitude =
      (Math.max(-85.0511, Math.min(85.0511, point.lat)) * Math.PI) / 180;
    return {
      x: (point.lng + 180) / 360,
      y: (1 - Math.log(Math.tan(Math.PI / 4 + latitude / 2)) / Math.PI) / 2,
    };
  };
  let minX = Infinity,
    maxX = -Infinity,
    minY = Infinity,
    maxY = -Infinity;
  for (const point of points) {
    const { x, y } = project(point);
    minX = Math.min(minX, x);
    maxX = Math.max(maxX, x);
    minY = Math.min(minY, y);
    maxY = Math.max(maxY, y);
  }
  const centerX = (minX + maxX) / 2,
    centerY = (minY + maxY) / 2;
  const lng = Number((centerX * 360 - 180).toFixed(7));
  const lat = Number(
    (
      (Math.atan(Math.sinh(Math.PI * (1 - 2 * centerY))) * 180) /
      Math.PI
    ).toFixed(7)
  );
  // Mapbox rounds zoom to two decimals; use that same camera for marker positions.
  const zoom =
    Math.floor(
      Math.min(
        22,
        Math.max(
          0,
          Math.log2(
            Math.min(
              1110 / Math.max(maxX - minX, 1e-9),
              610 / Math.max(maxY - minY, 1e-9)
            ) / 512
          )
        )
      ) * 100
    ) / 100;
  const center = project({ lat, lng });
  const scale = 512 * 2 ** zoom;
  const pixel = (point: TrailPoint) => {
    const p = project(point);
    return {
      x: 600 + (p.x - center.x) * scale,
      y: 350 + (p.y - center.y) * scale,
    };
  };
  return {
    lng,
    lat,
    zoom,
    start: pixel(points[0]),
    finish: pixel(points.at(-1)!),
  };
}

// Mapbox Static Images accepts precision-5 encoded paths and URLs up to 8192 chars.
export function encodedMapPath(points: TrailPoint[]) {
  let previousLat = 0,
    previousLng = 0;
  const encode = (delta: number) => {
    let value = delta < 0 ? ~(delta << 1) : delta << 1;
    let encoded = '';
    while (value >= 32) {
      encoded += String.fromCharCode((32 | (value & 31)) + 63);
      value >>>= 5;
    }
    return encoded + String.fromCharCode(value + 63);
  };
  return points
    .map((point) => {
      const lat = Math.round(point.lat * 1e5),
        lng = Math.round(point.lng * 1e5);
      const result = encode(lat - previousLat) + encode(lng - previousLng);
      previousLat = lat;
      previousLng = lng;
      return result;
    })
    .join('');
}
export function trailMapImageUrl(points: TrailPoint[], token: string) {
  if (points.length < 2) throw new Error('The recorded route is unavailable.');
  const camera = trailMapCamera(points);
  let stride = Math.max(1, Math.ceil(points.length / 850));
  while (true) {
    const sample = points.filter(
      (_, index) => index % stride === 0 || index === points.length - 1
    );
    const path = encodeURIComponent(encodedMapPath(sample));
    const overlay = `path-4+2d5dd3-1(${path})`;
    const url = `https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/${overlay}/${camera.lng},${camera.lat},${camera.zoom},0,0/1200x700?access_token=${encodeURIComponent(token)}`;
    if (url.length <= 8000) return url;
    stride *= 2;
  }
}
