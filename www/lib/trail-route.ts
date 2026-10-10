'use client';
import {collection, doc, getDoc, getDocs, orderBy, query} from 'firebase/firestore';
import {db} from './firebase';
import {decodeRouteChunks} from './route-geometry';

type Coordinates = [number, number][];
type CachedRoute = {revision: string; coordinates: Coordinates};
const routes = new Map<string, Promise<Coordinates>>();

// Cache only public trail geometry. Report locations and report data stay out of this store.
async function routeCache(key: string, value?: CachedRoute): Promise<CachedRoute | undefined> {
  if (typeof indexedDB === 'undefined') return;
  return new Promise<CachedRoute | undefined>(resolve => {
    let settled = false;
    const finish = (result?: CachedRoute) => {if (!settled) {settled = true; clearTimeout(timer); resolve(result);}};
    const timer = setTimeout(() => finish(), 1500);
    const request = indexedDB.open('eurotrex-public-routes', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('routes');
    request.onerror = () => finish(); request.onblocked = () => finish();
    request.onsuccess = () => {
      const cache = request.result;
      if (settled) {cache.close(); return;}
      let transaction: IDBTransaction;
      try {transaction = cache.transaction('routes', value ? 'readwrite' : 'readonly');}
      catch {cache.close(); finish(); return;}
      const store = transaction.objectStore('routes');
      const result = value ? store.put(value, key) : store.get(key);
      result.onsuccess = () => finish(value ? undefined : result.result);
      result.onerror = () => finish();
      transaction.oncomplete = transaction.onabort = () => cache.close();
    };
  }).catch(() => undefined);
}

async function fetchTrailRoute(trailId: string): Promise<Coordinates> {
  const metadata = await getDoc(doc(db, 'trails', trailId, 'routeMetadata', 'main'));
  if (!metadata.exists()) throw new Error('Trail geometry unavailable');
  const data = metadata.data();
  const revision = JSON.stringify([data.version, data.updatedAt?.toMillis?.(), data.pointCount, data.chunkCount]);
  const key = `${db.app.options.projectId}:${trailId}`;
  const cached = await routeCache(key);
  if (cached?.revision === revision && Array.isArray(cached.coordinates) && cached.coordinates.length === data.pointCount
    && cached.coordinates.every(p => Array.isArray(p) && p.length === 2 && Number.isFinite(p[0]) && Number.isFinite(p[1]) && Math.abs(p[0]) <= 180 && Math.abs(p[1]) <= 90)) return cached.coordinates;
  const chunks = await getDocs(query(collection(db, 'trails', trailId, 'routeChunks'), orderBy('chunkIndex')));
  if (data.chunkCount != null && chunks.size !== Number(data.chunkCount)) throw new Error('Incomplete trail geometry');
  const coordinates = decodeRouteChunks(data, chunks.docs.map(chunk => chunk.data()));
  void routeCache(key, {revision, coordinates});
  return coordinates;
}

export function loadTrailRoute(trailId: string): Promise<Coordinates> {
  let route = routes.get(trailId);
  if (!route) {
    route = fetchTrailRoute(trailId).catch(error => {routes.delete(trailId); throw error;});
    routes.set(trailId, route);
  }
  return route;
}
export function preloadTrailRoutes(trailIds: string[]) {
  const queue = [...trailIds];
  const worker = async () => {while (queue.length) {const id = queue.shift()!; try {await loadTrailRoute(id);} catch {/* The map shows a retry if this route is opened. */}}};
  void Promise.all([worker(), worker()]);
}
