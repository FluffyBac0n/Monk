'use client';
import {doc, onSnapshot} from 'firebase/firestore';
import {db} from './firebase';
import {eraCall, type EraAccess} from './era';
import {clearCurrentEraRoutes} from './era-current-route';

// Metadata/reconnect notifications must not tear down the map or unsaved review.
// Actual permission changes still invalidate the workspace before revalidation.
export function watchEraAccess(userId: string, callbacks: {
  pending: () => void; receive: (access: EraAccess) => void; fail: (error: Error) => void;
}) {
  const collections = ['eraMembers', 'trailReportAccess', 'admins'];
  const documents = new Map<string, string>();
  let stopped = false, generation = 0;
  const stops: (() => void)[] = [];
  let timeout: ReturnType<typeof setTimeout>;
  function armTimeout() {
    clearTimeout(timeout);
    timeout = setTimeout(() => fail(new Error('Connecting to trail access is taking too long. Check your connection and try again.')), 12000);
  }
  armTimeout();
  callbacks.pending();
  function fail(error: Error) {
    if (stopped) return;
    stopped = true; generation++; clearTimeout(timeout);
    stops.forEach(stop => stop());
    clearCurrentEraRoutes(); callbacks.fail(error);
  }
  for (const collection of collections) {
    stops.push(onSnapshot(doc(db, collection, userId), {includeMetadataChanges: true}, snapshot => {
      if (stopped || snapshot.metadata.fromCache) return;
      const value = JSON.stringify(snapshot.data() ?? null);
      if (documents.get(collection) === value) return;
      documents.set(collection, value);
      if (documents.size !== collections.length) return;
      const current = ++generation;
      clearCurrentEraRoutes(); callbacks.pending(); armTimeout();
      void eraCall<EraAccess>('getEraAccess').then(access => {
        if (!stopped && current === generation) {clearTimeout(timeout); callbacks.receive(access);}
      }, error => {if (current === generation) fail(error);});
    }, fail));
  }
  return () => {stopped = true; generation++; clearTimeout(timeout); stops.forEach(stop => stop());};
}
