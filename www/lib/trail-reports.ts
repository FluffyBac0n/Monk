'use client';
import {httpsCallable} from 'firebase/functions';
import {collection, doc, getDoc, getDocs, onSnapshot, query, where, orderBy, limit, type Timestamp} from 'firebase/firestore';
import type {User} from 'firebase/auth';
import {db, reportFunctions} from './firebase';
import {userIsAdmin} from './accommodations';
export const reportCategories: Record<string, string> = {signpost: 'Signpost', vegetation: 'Vegetation', obstruction: 'Obstruction / rockfall', path_damage: 'Damaged path', other: 'Other'};
export const reportStatuses = ['new', 'reviewed', 'forwarded', 'resolved', 'duplicate', 'dismissed'];
export type ReportPhoto = {id: string; path: string; thumbnailPath: string};
export type TrailReport = {
  id: string; trailId: string; stageId?: string; category: string; description: string;
  passability: string; latitude: number; longitude: number; accuracyM?: number;
  locationSource: string; contactEmail?: string; observedAtMs: number;
  receivedAt: Timestamp; updatedAt: Timestamp; status: string; priority: string;
  authority: string; forwardingReference: string; duplicateOf?: string; photos: ReportPhoto[];
};
export type Trail = {id: string; name: string};
export type ReportEvent = {id: string; action: string; status?: string; note?: string; actorEmail?: string; authority?: string; forwardingReference?: string; createdAt?: Timestamp};
export async function reportAccess(user: User) {
  const admin = await userIsAdmin(user);
  const membership = await getDoc(doc(db, 'trailReportAccess', user.uid));
  const ids: string[] = membership.data()?.trailIds || [];
  const trails = admin ? (await getDocs(collection(db, 'trails'))).docs
    : (await Promise.all(ids.map(id => getDoc(doc(db, 'trails', id))))).filter(item => item.exists());
  return {admin, trails: trails.map(item => ({id: item.id, name: String(item.data()?.name || item.id)}))};
}
export function watchTrailReports(trailId: string, status: string, category: string, count: number, fromDate: string,
  receive: (rows: TrailReport[]) => void, fail: (error: Error) => void) {
  return onSnapshot(query(collection(db, 'trailReports'), where('trailId', '==', trailId), where('uploadState', '==', 'complete'),
    ...(status ? [where('status', '==', status)] : []), ...(category ? [where('category', '==', category)] : []),
    ...(fromDate ? [where('receivedAt', '>=', new Date(fromDate))] : []), orderBy('receivedAt', 'desc'), limit(count)),
    snapshot => receive(snapshot.docs.map(d => ({...d.data(), id: d.id}) as TrailReport)), fail);
}
export function watchReportEvents(id: string, receive: (rows: ReportEvent[]) => void, fail: (error: Error) => void) {
  return onSnapshot(query(collection(db, 'trailReports', id, 'events'), orderBy('createdAt', 'desc'), limit(100)),
    snapshot => receive(snapshot.docs.map(d => ({...d.data(), id: d.id}) as ReportEvent)), fail);
}
export async function reportPhoto(reportId: string, photoId: string, thumbnail: boolean) {
  const result = await httpsCallable<{reportId: string; photoId: string; thumbnail: boolean}, {data: string; contentType: string}>(reportFunctions, 'trailReportPhoto')({reportId, photoId, thumbnail});
  return `data:image/jpeg;base64,${result.data.data}`;
}
export async function reviewReport(report: TrailReport, changes: Record<string, string>) {
  await httpsCallable(reportFunctions, 'reviewTrailReport')({reportId: report.id, updatedAtMs: report.updatedAt.toMillis(), ...changes});
}
export async function setReportAccess(email: string, trailId: string, grant: boolean) {
  await httpsCallable(reportFunctions, 'setTrailReportAccess')({email, trailId, grant});
}
export const reportMapUrl = (report: TrailReport) => `https://www.google.com/maps/search/?api=1&query=${report.latitude},${report.longitude}`;
export function forwardingText(report: TrailReport, trailName: string) {
  return `EuroTrex trail problem report\nReference: ${report.id}\nTrail: ${trailName}\nStage: ${report.stageId || 'Not assigned'}\nProblem: ${reportCategories[report.category] || report.category}\nTrail access: ${report.passability}\nPriority: ${report.priority}\nObserved: ${new Date(report.observedAtMs).toISOString()}\nLocation: ${report.latitude}, ${report.longitude}\n${reportMapUrl(report)}\n\n${report.description}\n\nPlease quote the report reference in your reply to EuroTrex.`;
}
const escape = (s: string) => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
export function reportPrintHtml(report: TrailReport, trailName: string, photos: string[]) {
  return `<!doctype html><html><head><meta charset="utf-8"><title>EuroTrex report ${escape(report.id)}</title><style>body{font:15px system-ui;max-width:850px;margin:35px auto;color:#173651}pre{white-space:pre-wrap;font:inherit;line-height:1.6}img{max-width:100%;max-height:420px;display:block;margin:20px 0;break-inside:avoid}@media print{button{display:none}}</style></head><body><button onclick="window.print()">Print / Save as PDF</button><h1>Trail problem report</h1><pre>${escape(forwardingText(report, trailName))}</pre>${photos.map(src => `<img src="${src}" alt="Report photo">`).join('')}</body></html>`;
}
export function reportEmail(report: TrailReport, trailName: string, photos: string[]) {
  const boundary = `eurotrex_${report.id}`;
  const base64Text = btoa(Array.from(new TextEncoder().encode(forwardingText(report, trailName)), c => String.fromCharCode(c)).join(''));
  const wrap = (value: string) => value.match(/.{1,76}/g)?.join('\r\n') || '';
  return `Subject: EuroTrex trail report ${report.id}\r\nX-Unsent: 1\r\nMIME-Version: 1.0\r\nContent-Type: multipart/mixed; boundary="${boundary}"\r\n\r\n--${boundary}\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n${wrap(base64Text)}\r\n${photos.map((photo, i) => `--${boundary}\r\nContent-Type: image/jpeg\r\nContent-Disposition: attachment; filename="trail-photo-${i+1}.jpg"\r\nContent-Transfer-Encoding: base64\r\n\r\n${wrap(photo.split(',')[1])}\r\n`).join('')}--${boundary}--\r\n`;
}
export function downloadFile(filename: string, content: string, type: string) {
  const url = URL.createObjectURL(new Blob([content], {type}));
  const link = document.createElement('a'); link.href = url; link.download = filename; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
