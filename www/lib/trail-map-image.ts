import type { TrailPoint } from './public-trail-data';

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
  let stride = Math.max(1, Math.ceil(points.length / 850));
  while (true) {
    const sample = points.filter(
      (_, index) => index % stride === 0 || index === points.length - 1
    );
    const first = sample[0],
      last = sample.at(-1)!;
    const path = encodeURIComponent(encodedMapPath(sample));
    const overlay = `path-4+2d5dd3-1(${path}),pin-s-a+f2c94c(${first.lng},${first.lat}),pin-s-b+303e4e(${last.lng},${last.lat})`;
    const url = `https://api.mapbox.com/styles/v1/mapbox/outdoors-v12/static/${overlay}/auto/1200x700?padding=45&access_token=${encodeURIComponent(token)}`;
    if (url.length <= 8000) return url;
    stride *= 2;
  }
}
