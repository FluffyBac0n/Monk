export function decodeRouteChunks(metadata: Record<string, unknown>, chunks: Record<string, unknown>[]): [number, number][] {
  const format = Array.isArray(metadata.pointFormat) ? metadata.pointFormat : ['lat', 'lng'];
  const stride = Number(metadata.pointStride ?? format.length);
  const latIndex = format.indexOf('lat'), lngIndex = format.indexOf('lng');
  if (!Number.isInteger(stride) || stride < 2 || latIndex < 0 || lngIndex < 0 || Math.max(latIndex, lngIndex) >= stride) throw new Error('Unsupported trail geometry');
  const coordinates: [number, number][] = [];
  for (const chunk of chunks) {
    if (!Array.isArray(chunk.points) || chunk.points.length % stride) throw new Error('Incomplete trail geometry');
    for (let i = 0; i < chunk.points.length; i += stride) {
      const lat = chunk.points[i + latIndex], lng = chunk.points[i + lngIndex];
      if (typeof lat !== 'number' || typeof lng !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new Error('Invalid trail coordinate');
      coordinates.push([lng, lat]);
    }
  }
  if (coordinates.length < 2) throw new Error('Trail geometry unavailable');
  if (metadata.pointCount != null && coordinates.length !== Number(metadata.pointCount)) throw new Error('Incomplete trail geometry');
  return coordinates;
}

