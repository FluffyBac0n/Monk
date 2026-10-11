'use client';
import {collection, doc, getDocsFromServer, onSnapshot} from 'firebase/firestore';
import type {User} from 'firebase/auth';
import {db} from './firebase';
import type {Trail} from './trail-reports';

export type ReportAccess = {admin: boolean; trails: Trail[]};
export type AccessState = {status: 'loading'} | {status: 'ready'; access: ReportAccess} | {status: 'error'; message: string};

export function reportLoadError(error: unknown, subject: string) {
  const code = String((error as {code?: string})?.code || 'unknown');
  // Keep diagnostic codes, but never log report contents, tokens or personal details.
  console.warn(`[Trail reports] ${subject}: ${code}`);
  if (code === 'permission-denied') return `${subject === 'trail access' ? 'Firebase could not verify your trail permissions.' : 'Your account could not access these reports.'} Try again, or sign out and sign in to refresh your session.`;
  if (code.startsWith('auth/') || code === 'unauthenticated') return 'Your sign-in session could not be verified. Try again, or sign out and sign in.';
  if (code === 'failed-precondition') return `Firebase could not load ${subject}. Please contact EuroTrex support.`;
  return `Could not connect to load ${subject}. Check your connection and try again.`;
}

// One live subscription per permission document. Reuse the delivered values instead
// of starting another token refresh and another membership read on each snapshot.
export function watchReportAccess(user: User, receive: (state: AccessState) => void) {
  let stopped = false, generation = 0;
  let adminDocument: boolean | undefined, claim: boolean | undefined, ids: string[] | undefined;
  let lastKey = '';
  let timer: ReturnType<typeof setTimeout>;
  const stops: (() => void)[] = [];
  function pending() {
    clearTimeout(timer);
    receive({status: 'loading'});
    timer = setTimeout(() => {
      if (!stopped) receive({status: 'error', message: 'Connecting to Firebase is taking too long. Check your connection and try again.'});
    }, 12000);
  }
  function fail(error: unknown) {
    if (stopped) return;
    stopped = true; generation++; clearTimeout(timer);
    stops.forEach(stop => stop());
    receive({status: 'error', message: reportLoadError(error, 'trail access')});
  }
  async function resolve() {
    if (stopped || adminDocument === undefined || claim === undefined || ids === undefined) return;
    const admin = claim || adminDocument;
    const key = JSON.stringify([admin, ids]);
    if (key === lastKey) return;
    lastKey = key;
    const current = ++generation;
    pending(); // Clear previously granted access immediately when membership changes.
    try {
      // Trail names are public. One small catalog read avoids N serial document reads.
      const catalog = admin || ids.length ? await getDocsFromServer(collection(db, 'trails')) : null;
      if (stopped || current !== generation) return;
      const trails = (catalog?.docs || []).filter(item => admin || ids!.includes(item.id))
        .map(item => ({id: item.id, name: String(item.data()?.name || item.id)}));
      clearTimeout(timer);
      receive({status: 'ready', access: {admin, trails}});
    } catch (error) {if (current === generation) fail(error);}
  }
  pending();
  // Firebase refreshes expired tokens itself. Forcing a refresh for every snapshot
  // adds an unnecessary network dependency to opening the reports page.
  void user.getIdTokenResult().then(token => {claim = token.claims.admin === true; void resolve();}, fail);
  stops.push(onSnapshot(doc(db, 'admins', user.uid), {includeMetadataChanges: true}, snapshot => {
    if (snapshot.metadata.fromCache) return;
    adminDocument = snapshot.exists(); void resolve();
  }, fail));
  stops.push(onSnapshot(doc(db, 'trailReportAccess', user.uid), {includeMetadataChanges: true}, snapshot => {
    if (snapshot.metadata.fromCache) return;
    const values: unknown = snapshot.data()?.trailIds;
    ids = Array.isArray(values) ? [...new Set(values.filter((id): id is string => typeof id === 'string'))].sort() : [];
    void resolve();
  }, fail));
  return () => {stopped = true; generation++; clearTimeout(timer); stops.forEach(stop => stop());};
}
