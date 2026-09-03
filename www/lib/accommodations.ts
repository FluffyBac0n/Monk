'use client';

import type { User } from 'firebase/auth';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  query,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
  type DocumentData,
  type Unsubscribe,
} from 'firebase/firestore';
import { db } from './firebase';
import type {
  AccommodationSubmission,
  AuditEntry,
  PublishedLodging,
  StageOption,
  SubmissionStatus,
  TrailOption,
} from './models';

const submissions = collection(db, 'accommodationSubmissions');

function sortedSubmissions(rows: AccommodationSubmission[]) {
  return rows.sort((a, b) => a.name.localeCompare(b.name));
}

function submissionFromDoc(id: string, data: DocumentData): AccommodationSubmission {
  return { id, ...data } as AccommodationSubmission;
}

export async function registerOwnerProfile(user: User, businessName = '') {
  await setDoc(
    doc(db, 'ownerProfiles', user.uid),
    {
      email: user.email || '',
      businessName,
      updatedAt: serverTimestamp(),
      createdAt: serverTimestamp(),
    },
    { merge: true },
  );
}

export function watchOwnerSubmissions(
  ownerId: string,
  onData: (rows: AccommodationSubmission[]) => void,
  onError: (error: Error) => void,
): Unsubscribe {
  return onSnapshot(
    query(submissions, where('ownerId', '==', ownerId)),
    (snapshot) => onData(sortedSubmissions(snapshot.docs.map((row) => submissionFromDoc(row.id, row.data())))),
    onError,
  );
}

export function watchAllSubmissions(
  onData: (rows: AccommodationSubmission[]) => void,
  onError: (error: Error) => void,
): Unsubscribe {
  return onSnapshot(
    submissions,
    (snapshot) => onData(sortedSubmissions(snapshot.docs.map((row) => submissionFromDoc(row.id, row.data())))),
    onError,
  );
}

export async function listTrails(): Promise<TrailOption[]> {
  const snapshot = await getDocs(collection(db, 'trails'));
  const rows = snapshot.docs.map((row) => ({ id: row.id, name: String(row.data().name || row.id) }));
  return rows.length ? rows : [{ id: 'cyprus-e4', name: 'E4 — Cyprus' }];
}

export async function listStages(trailId: string): Promise<StageOption[]> {
  const snapshot = await getDocs(collection(db, 'trails', trailId, 'stages'));
  return snapshot.docs
    .map((row) => ({ id: row.id, name: String(row.data().name || row.id), sequence: Number(row.data().sequence || 0) }))
    .sort((a, b) => b.sequence - a.sequence);
}

export async function saveSubmission(
  user: User,
  values: Omit<AccommodationSubmission, 'id' | 'ownerId' | 'ownerEmail' | 'status'>,
  existing?: AccommodationSubmission,
) {
  const record = existing ? doc(db, 'accommodationSubmissions', existing.id) : doc(submissions);
  const status: SubmissionStatus = existing?.status === 'approved' || existing?.status === 'pending_update'
    ? 'pending_update'
    : 'pending';
  await setDoc(
    record,
    {
      ...values,
      ownerId: user.uid,
      ownerEmail: user.email || '',
      status,
      reviewNote: '',
      updatedAt: serverTimestamp(),
      ...(existing ? {} : { createdAt: serverTimestamp() }),
    },
    { merge: true },
  );
  return record.id;
}

function publicLodgingData(submission: AccommodationSubmission) {
  return {
    trailId: submission.trailId,
    stageId: submission.stageId,
    stageName: submission.stageName,
    stageSequence: submission.stageSequence || null,
    name: submission.name,
    type: submission.type,
    village: submission.village,
    address: submission.address,
    description: submission.description,
    priceMinEur: submission.priceMinEur || null,
    priceMaxEur: submission.priceMaxEur || null,
    minPriceText: submission.priceMinEur ? `From €${submission.priceMinEur}` : null,
    contact: {
      phone: submission.phone,
      whatsapp: submission.whatsapp || '',
      email: submission.email,
      website: submission.website,
      googleMapsUrl: submission.googleMapsUrl || '',
    },
    distanceFromTrailKm: submission.distanceFromTrailKm ?? null,
    capacityPeople: submission.capacityPeople ?? null,
    monthsOpen: submission.monthsOpen || '',
    location: submission.latitude != null && submission.longitude != null
      ? { latitude: submission.latitude, longitude: submission.longitude }
      : null,
    ownerId: submission.ownerId,
    sourceSubmissionId: submission.id,
    approvedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  };
}

async function addAudit(
  batch: ReturnType<typeof writeBatch>,
  actor: User,
  submission: AccommodationSubmission | null,
  action: string,
  note: string,
  trailId?: string,
  lodgingId?: string,
) {
  batch.set(doc(collection(db, 'accommodationAudit')), {
    submissionId: submission?.id || '',
    lodgingId: lodgingId || submission?.publishedLodgingId || submission?.id || '',
    trailId: trailId || submission?.trailId || '',
    ownerId: submission?.ownerId || '',
    accommodationName: submission?.name || '',
    action,
    note,
    actorId: actor.uid,
    actorEmail: actor.email || '',
    createdAt: serverTimestamp(),
  });
}

export async function approveSubmission(actor: User, submission: AccommodationSubmission, note = '') {
  const batch = writeBatch(db);
  const lodgingId = submission.publishedLodgingId || submission.id;
  batch.set(doc(db, 'trails', submission.trailId, 'lodgings', lodgingId), publicLodgingData(submission), { merge: true });
  batch.update(doc(db, 'accommodationSubmissions', submission.id), {
    status: 'approved',
    publishedLodgingId: lodgingId,
    reviewNote: note,
    reviewedBy: actor.uid,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await addAudit(batch, actor, submission, 'approved', note, submission.trailId, lodgingId);
  await batch.commit();
}

export async function reviewSubmission(
  actor: User,
  submission: AccommodationSubmission,
  status: Extract<SubmissionStatus, 'changes_requested' | 'rejected'>,
  note: string,
) {
  const batch = writeBatch(db);
  batch.update(doc(db, 'accommodationSubmissions', submission.id), {
    status,
    reviewNote: note,
    reviewedBy: actor.uid,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await addAudit(batch, actor, submission, status, note);
  await batch.commit();
}

export async function removeSubmissionAccommodation(actor: User, submission: AccommodationSubmission, note: string) {
  const batch = writeBatch(db);
  const lodgingId = submission.publishedLodgingId || submission.id;
  batch.delete(doc(db, 'trails', submission.trailId, 'lodgings', lodgingId));
  batch.update(doc(db, 'accommodationSubmissions', submission.id), {
    status: 'removed',
    reviewNote: note,
    reviewedBy: actor.uid,
    reviewedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  await addAudit(batch, actor, submission, 'removed', note, submission.trailId, lodgingId);
  await batch.commit();
}

export function watchPublishedLodgings(
  trailId: string,
  onData: (rows: PublishedLodging[]) => void,
  onError: (error: Error) => void,
) {
  return onSnapshot(
    collection(db, 'trails', trailId, 'lodgings'),
    (snapshot) => onData(snapshot.docs.map((row) => ({ id: row.id, trailId, ...row.data() } as PublishedLodging)).sort((a, b) => (a.name || '').localeCompare(b.name || ''))),
    onError,
  );
}

export function watchAllPublishedLodgings(
  onData: (rows: PublishedLodging[]) => void,
  onError: (error: Error) => void,
) {
  return onSnapshot(
    collectionGroup(db, 'lodgings'),
    (snapshot) => onData(snapshot.docs.map((row) => ({
      id: row.id,
      trailId: row.ref.parent.parent?.id || '',
      ...row.data(),
    } as PublishedLodging)).sort((a, b) => (a.name || '').localeCompare(b.name || ''))),
    onError,
  );
}

export function watchAudit(
  onData: (rows: AuditEntry[]) => void,
  onError: (error: Error) => void,
) {
  return onSnapshot(
    collection(db, 'accommodationAudit'),
    (snapshot) => onData(snapshot.docs.map((row) => ({ id: row.id, ...row.data() } as AuditEntry)).sort((a, b) => {
      const left = a.createdAt?.toDate?.().getTime() || 0;
      const right = b.createdAt?.toDate?.().getTime() || 0;
      return right - left;
    })),
    onError,
  );
}

export async function removePublishedLodging(actor: User, lodging: PublishedLodging, note: string) {
  const batch = writeBatch(db);
  batch.delete(doc(db, 'trails', lodging.trailId, 'lodgings', lodging.id));
  await addAudit(batch, actor, null, 'removed', note, lodging.trailId, lodging.id);
  if (lodging.sourceSubmissionId) {
    batch.update(doc(db, 'accommodationSubmissions', lodging.sourceSubmissionId), {
      status: 'removed',
      reviewNote: note,
      reviewedBy: actor.uid,
      reviewedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  }
  await batch.commit();
}

export async function userIsAdmin(user: User) {
  const token = await user.getIdTokenResult(true);
  if (token.claims.admin === true) return true;
  return (await getDoc(doc(db, 'admins', user.uid))).exists();
}

export async function deleteDraft(user: User, submission: AccommodationSubmission) {
  if (submission.ownerId !== user.uid || !['draft', 'rejected', 'changes_requested'].includes(submission.status)) return;
  await deleteDoc(doc(db, 'accommodationSubmissions', submission.id));
}
