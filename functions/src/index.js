import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, GeoPoint, Timestamp, getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {onCall, HttpsError} from 'firebase-functions/v2/https';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {createHash} from 'node:crypto';
import sharp from 'sharp';
import {requireId, validateReport, validateReview, mayReview} from './report-model.js';

initializeApp();
const db = getFirestore();
const bucket = getStorage().bucket();
// Production always requires verified app attestation. Local emulators cannot
// obtain real device attestations and never connect to production resources.
// Firebase clients carry Firebase Auth and App Check tokens, not Cloud IAM
// invoker tokens. Allow transport access; every callable still verifies both
// tokens and applies its report ownership/trail membership checks below.
const options = {region: 'europe-west1', invoker: 'public', memory: '512MiB', maxInstances: 5, concurrency: 2, timeoutSeconds: 120,
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true'};
const callable = (handler) => onCall(options, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in before continuing.');
  try { return await handler(request); }
  catch (error) {
    if (error instanceof HttpsError) throw error;
    // Never return storage URLs, credentials, or internal errors to a client.
    console.error('Trail report operation failed', {code: error.code || 'internal', name: error.name});
    throw new HttpsError('internal', 'The request could not be completed. Please retry.');
  }
});
function validate(fn) { try { return fn(); } catch (e) { throw new HttpsError('invalid-argument', e.message); } }
async function access(auth) {
  const verified = auth.token.email_verified === true;
  if (!verified) return {verified: false, admin: false, trailIds: []};
  const [admin, member] = await Promise.all([db.doc(`admins/${auth.uid}`).get(), db.doc(`trailReportAccess/${auth.uid}`).get()]);
  return {verified, admin: auth.token.admin === true || admin.exists, trailIds: member.data()?.trailIds || []};
}
async function assertAdmin(auth) {
  if (!(await access(auth)).admin) throw new HttpsError('permission-denied', 'Administrator access is required.');
}
async function readableReport(request) {
  const reportId = validate(() => requireId(request.data.reportId));
  const snapshot = await db.doc(`trailReports/${reportId}`).get();
  if (!snapshot.exists || !mayReview(await access(request.auth), snapshot.data().trailId)) throw new HttpsError('permission-denied', 'You cannot access this report.');
  return snapshot;
}

export const beginTrailReport = callable(async ({auth, data}) => {
  const reportId = validate(() => requireId(data.reportId));
  const body = validate(() => validateReport(data));
  const trail = await db.doc(`trails/${body.trailId}`).get();
  if (!trail.exists) throw new HttpsError('invalid-argument', 'This trail is unavailable.');
  if (body.stageId && !(await db.doc(`trails/${body.trailId}/stages/${body.stageId}`).get()).exists) body.stageId = null;
  const fingerprint = createHash('sha256').update(JSON.stringify(body)).digest('hex');
  const report = db.doc(`trailReports/${reportId}`);
  const day = new Date().toISOString().slice(0, 10);
  const userQuota = db.doc(`trailReportQuotas/${auth.uid}_${day}`);
  const globalQuota = db.doc(`trailReportQuotas/global_${day}`);
  return db.runTransaction(async (tx) => {
    const [existing, own, global] = await tx.getAll(report, userQuota, globalQuota);
    if (existing.exists) {
      if (existing.data().reporterUid !== auth.uid || existing.data().fingerprint !== fingerprint) throw new HttpsError('already-exists', 'This submission identifier is already in use.');
      return {reportId, received: existing.data().uploadState === 'complete'};
    }
    if ((own.data()?.count || 0) >= 10 || (global.data()?.count || 0) >= 1000) throw new HttpsError('resource-exhausted', 'The daily report limit has been reached. Please try tomorrow.');
    const expiresAt = Timestamp.fromMillis(Date.now() + 3 * 86400000);
    for (const [ref, snap] of [[userQuota, own], [globalQuota, global]]) tx.set(ref, {count: (snap.data()?.count || 0) + 1, expiresAt});
    tx.create(report, {...body, location: new GeoPoint(body.latitude, body.longitude), reporterUid: auth.uid,
      fingerprint, uploadState: 'uploading', status: 'new', priority: 'normal', photos: [],
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), receivedAt: null,
      authority: '', forwardingReference: '', duplicateOf: null});
    return {reportId, received: false};
  });
});

export const finalizeTrailReport = callable(async ({auth, data}) => {
  const reportId = validate(() => requireId(data.reportId));
  const ref = db.doc(`trailReports/${reportId}`);
  const snap = await ref.get();
  if (!snap.exists || snap.data().reporterUid !== auth.uid) throw new HttpsError('permission-denied', 'You cannot submit this report.');
  const report = snap.data();
  if (report.uploadState === 'complete') return {reportId, received: true};
  if (report.uploadState !== 'uploading') throw new HttpsError('failed-precondition', 'This draft expired. Create a new report.');
  const photos = [];
  for (const id of report.photoIds) {
    const source = bucket.file(`trail-report-uploads/${auth.uid}/${reportId}/${id}/photo.jpg`);
    const [exists] = await source.exists();
    if (!exists) throw new HttpsError('failed-precondition', 'Some photos have not finished uploading.');
    const [meta] = await source.getMetadata();
    if (Number(meta.size) > 2 * 1024 * 1024) throw new HttpsError('invalid-argument', 'Photo is too large.');
    const [bytes] = await source.download();
    let full, thumb;
    try {
      const image = sharp(bytes, {limitInputPixels: 24_000_000, animated: false}).rotate();
      const metadata = await image.metadata();
      if (!['jpeg', 'png', 'webp'].includes(metadata.format)) throw new Error('Invalid image');
      full = await image.clone().resize({width: 1800, height: 1800, fit: 'inside', withoutEnlargement: true}).jpeg({quality: 80}).toBuffer();
      thumb = await image.clone().resize({width: 360, height: 360, fit: 'inside', withoutEnlargement: true}).jpeg({quality: 70}).toBuffer();
    } catch { throw new HttpsError('invalid-argument', 'A photo cannot be read. Please replace it.'); }
    const path = `trail-report-media/${reportId}/${id}.jpg`;
    const thumbnailPath = `trail-report-media/${reportId}/${id}-thumb.jpg`;
    await Promise.all([[path, full], [thumbnailPath, thumb]].map(([name, buffer]) => bucket.file(name).save(buffer, {
      resumable: false, metadata: {contentType: 'image/jpeg', cacheControl: 'private, no-store'},
    })));
    photos.push({id, path, thumbnailPath, bytes: full.length});
  }
  await db.runTransaction(async (tx) => {
    const latest = await tx.get(ref);
    if (latest.data()?.uploadState === 'complete') return;
    if (latest.data()?.uploadState !== 'uploading') throw new HttpsError('failed-precondition', 'This draft expired.');
    tx.update(ref, {photos, uploadState: 'complete', receivedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    tx.create(ref.collection('events').doc('submitted'), {action: 'submitted', actorId: auth.uid, createdAt: FieldValue.serverTimestamp()});
  });
  await bucket.deleteFiles({prefix: `trail-report-uploads/${auth.uid}/${reportId}/`}).catch(() => {});
  return {reportId, received: true};
});

export const trailReportReceipt = callable(async ({auth, data}) => {
  const id = validate(() => requireId(data.reportId));
  const report = await db.doc(`trailReports/${id}`).get();
  if (!report.exists || report.data().reporterUid !== auth.uid) throw new HttpsError('permission-denied', 'Receipt unavailable.');
  // Only a receipt, never report content or internal notes, is returned to hikers.
  return {reportId: id, received: report.data().uploadState === 'complete', status: report.data().uploadState === 'complete' ? report.data().status : 'uploading'};
});

export const trailReportPhoto = callable(async (request) => {
  const snap = await readableReport(request);
  const photoId = validate(() => requireId(request.data.photoId));
  const photo = snap.data().photos.find((item) => item.id === photoId);
  if (!photo || snap.data().uploadState !== 'complete') throw new HttpsError('not-found', 'Photo unavailable.');
  const [bytes] = await bucket.file(request.data.thumbnail === true ? photo.thumbnailPath : photo.path).download();
  return {data: bytes.toString('base64'), contentType: 'image/jpeg'};
});

export const reviewTrailReport = callable(async (request) => {
  const snap = await readableReport(request);
  const change = validate(() => validateReview(request.data, snap.id));
  const event = snap.ref.collection('events').doc();
  // Recheck membership in the transaction so revocation cannot race a review.
  await db.runTransaction(async (tx) => {
    const [current, member, admin] = await tx.getAll(snap.ref, db.doc(`trailReportAccess/${request.auth.uid}`), db.doc(`admins/${request.auth.uid}`));
    if (!mayReview({verified: request.auth.token.email_verified === true, admin: request.auth.token.admin === true || admin.exists, trailIds: member.data()?.trailIds}, current.data()?.trailId)) throw new HttpsError('permission-denied', 'Trail access was removed.');
    if (current.data().uploadState !== 'complete') throw new HttpsError('failed-precondition', 'Report is not ready for review.');
    if (change.duplicateOf) {
      const other = await tx.get(db.doc(`trailReports/${change.duplicateOf}`));
      if (!other.exists || other.data().trailId !== current.data().trailId || other.data().uploadState !== 'complete') throw new HttpsError('invalid-argument', 'Choose a received report for the same trail.');
    }
    if (request.data.updatedAtMs !== current.data().updatedAt.toMillis()) throw new HttpsError('aborted', 'Another user updated this report. Refresh before saving.');
    const {note, ...fields} = change;
    tx.update(snap.ref, {...fields, updatedAt: FieldValue.serverTimestamp(), reviewedBy: request.auth.uid});
    tx.create(event, {action: 'review', ...change, previousStatus: current.data().status,
      actorId: request.auth.uid, actorEmail: request.auth.token.email, createdAt: FieldValue.serverTimestamp()});
  });
  return {saved: true};
});

export const setTrailReportAccess = callable(async ({auth, data}) => {
  await assertAdmin(auth);
  const trailId = validate(() => requireId(data.trailId));
  if (typeof data.email !== 'string' || !data.email.trim() || typeof data.grant !== 'boolean') throw new HttpsError('invalid-argument', 'Enter an account email and access action.');
  if (!(await db.doc(`trails/${trailId}`).get()).exists) throw new HttpsError('invalid-argument', 'Unknown trail.');
  let user;
  try { user = await getAuth().getUserByEmail(data.email.trim()); }
  catch { throw new HttpsError('not-found', 'Ask this user to create an account at /trail-reports and verify their email first.'); }
  if (data.grant && (!user.emailVerified || user.disabled)) throw new HttpsError('failed-precondition', 'The user must verify their email first.');
  const batch = db.batch();
  batch.set(db.doc(`trailReportAccess/${user.uid}`), {email: user.email,
    trailIds: data.grant ? FieldValue.arrayUnion(trailId) : FieldValue.arrayRemove(trailId), updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  batch.create(db.collection('trailReportAccessAudit').doc(), {trailId, userId: user.uid, action: data.grant ? 'granted' : 'revoked', actorId: auth.uid, createdAt: FieldValue.serverTimestamp()});
  await batch.commit();
  return {saved: true};
});

export const cleanTrailReportUploads = onSchedule({schedule: 'every 24 hours', region: 'europe-west1', memory: '256MiB', maxInstances: 1}, async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - 14 * 86400000);
  const old = await db.collection('trailReports').where('uploadState', 'in', ['uploading', 'expired']).where('createdAt', '<', cutoff).limit(100).get();
  for (const doc of old.docs) {
    const claimed = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      if (!['uploading', 'expired'].includes(fresh.data()?.uploadState)) return false;
      tx.update(doc.ref, {uploadState: 'expired', updatedAt: FieldValue.serverTimestamp()}); return true;
    });
    if (!claimed) continue;
    try {
      await bucket.deleteFiles({prefix: `trail-report-uploads/${doc.data().reporterUid}/${doc.id}/`});
      await bucket.deleteFiles({prefix: `trail-report-media/${doc.id}/`});
      await doc.ref.update({uploadState: 'purged', updatedAt: FieldValue.serverTimestamp()});
    } catch {
      // Leave expired uploads eligible for the next cleanup run after a storage outage.
      console.error('Trail report upload cleanup needs retry', {reportId: doc.id});
    }
  }
  const quotas = await db.collection('trailReportQuotas').where('expiresAt', '<', Timestamp.now()).limit(400).get();
  const batch = db.batch(); quotas.docs.forEach((doc) => batch.delete(doc.ref)); await batch.commit();
});
