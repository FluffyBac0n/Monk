'use client';
import {useCallback, useEffect, useState} from 'react';
import type {User} from 'firebase/auth';
import {collection, doc, onSnapshot} from 'firebase/firestore';
import {AccountVerificationGate} from '@/components/AccountVerificationGate';
import {AuthPanel} from '@/components/AuthPanel';
import {PortalHeader} from '@/components/PortalHeader';
import {ReportSelect} from '@/components/ReportSelect';
import {ReportDatePicker} from '@/components/ReportDatePicker';
import {TrailReportMap} from '@/components/TrailReportMap';
import {ReportProgress, ReportReview, reportStatusLabels} from '@/components/ReportReview';
import {preloadTrailRoutes} from '@/lib/trail-route';
import {preloadReportMap} from '@/lib/report-map-runtime';
import {useAuthState} from '@/lib/use-auth';
import {db} from '@/lib/firebase';
import {reportAccess, watchTrailReports, watchReportEvents, reportCategories, reportStatuses, reportPhoto,
  setReportAccess, reportMapUrl, reportMapyUrl, reportPrintHtml, downloadFile,
  type TrailReport, type ReportEvent, type Trail} from '@/lib/trail-reports';

export default function TrailReportsPage() {
  const {user, loading} = useAuthState();
  useEffect(() => {void preloadReportMap().catch(() => {});}, []);
  if (loading) return <div className="loading-screen">Opening trail reports…</div>;
  if (!user) return <main className="portal-page trail-reports-page"><PortalHeader /><AuthPanel trailReports /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} />;
  return <ReportWorkspace key={user.uid} user={user} />;
}
function ReportWorkspace({user}: {user: User}) {
  const [access, setAccess] = useState<{admin: boolean; trails: Trail[]} | null>(null);
  const [trailId, setTrailId] = useState('');
  const [reviewMessage, setReviewMessage] = useState('');
  const [status, setStatus] = useState(''), [category, setCategory] = useState(''), [fromDate, setFromDate] = useState('');
  const [count, setCount] = useState(50), [rows, setRows] = useState<TrailReport[]>([]);
  const [selected, setSelected] = useState(''), [mapView, setMapView] = useState(false);
  const [error, setError] = useState(''), [loading, setLoading] = useState(true);
  useEffect(() => {
    let alive = true;
    const refresh = () => reportAccess(user).then(result => {
      if (!alive) return;
      preloadTrailRoutes(result.trails.map(trail => trail.id));
      setAccess(result); setTrailId(current => result.trails.some(t => t.id === current) ? current : result.trails[0]?.id || '');
    }).catch(() => { if (alive) {setAccess(null); setRows([]); setSelected(''); setError('Could not check trail access. Reload to retry.');} });
    void refresh();
    const stop = onSnapshot(doc(db, 'trailReportAccess', user.uid), () => {void refresh();}, () => {void refresh();});
    return () => {alive = false; stop();};
  }, [user]);
  useEffect(() => {
    setRows([]); setSelected(''); setCount(50);
  }, [trailId, status, category, fromDate]);
  useEffect(() => {
    if (!access || !trailId || !access.trails.some(t => t.id === trailId)) {setRows([]); setLoading(false); return;}
    setLoading(true); setError('');
    return watchTrailReports(trailId, status, category, count, fromDate, reports => {
      setRows(reports); setLoading(false);
      setSelected(current => reports.some(r => r.id === current) ? current : '');
    }, () => {setRows([]); setSelected(''); setLoading(false); setError('Reports could not be loaded. Your access may have changed; reload to retry.');});
  }, [access, trailId, status, category, count, fromDate]);
  const choose = useCallback((id: string) => setSelected(id), []);
  const current = rows.find(row => row.id === selected);
  const trailName = access?.trails.find(t => t.id === trailId)?.name || trailId;
  return <main className="portal-page trail-reports-page"><PortalHeader user={user} canAccessAdmin={access?.admin} /><div className="dashboard-shell wide">
    <section className="dashboard-title"><div><p className="eyebrow">TRAIL CARE</p><h1>Trail reports.</h1><p>Review problems, coordinate repairs and keep a record of what happens next.</p></div><span className="admin-badge">{access?.admin ? 'Admin' : 'Trail team'}</span></section>
    {error && <p className="notice error" role="alert">{error}</p>}
    {!access ? <p>Checking your assigned trails…</p> : !access.trails.length ? <section className="access-card"><h2>No trails assigned yet.</h2><p>Your email is verified. Ask a EuroTrex administrator to grant trail access to {user.email}.</p></section> : <>
      <section className="form-panel form-grid report-filters" aria-label="Filter reports">
        <ReportSelect label="Trail" value={trailId} onChange={setTrailId} options={access.trails.map(t => ({value: t.id, label: t.name}))} />
        <ReportSelect label="Status" value={status} onChange={setStatus} options={[{value: '', label: 'All statuses'}, ...reportStatuses.map(s => ({value: s, label: reportStatusLabels[s]}))]} />
        <ReportSelect label="Problem" value={category} onChange={setCategory} options={[{value: '', label: 'All problems'}, ...Object.entries(reportCategories).map(([value, label]) => ({value, label}))]} />
        <ReportDatePicker value={fromDate} onChange={setFromDate} />
        <button className="button button-secondary" aria-pressed={mapView} onClick={() => setMapView(v => !v)}>{mapView ? 'Hide map' : 'Show map'}</button>
      </section>
      {trailId && <TrailReportMap visible={mapView} key={trailId} trailId={trailId} trailName={trailName} reports={rows} selectedId={selected} onSelect={choose} />}
      {reviewMessage && <p className="notice" role="status">{reviewMessage}</p>}
      <p className="report-list-caption" role="status">{loading ? 'Loading reports…' : `${rows.length} reports loaded · newest first`}</p>
      <div className="report-workspace"><section className="report-inbox" aria-label="Reports">
        {!loading && !rows.length && <div className="empty-state report-empty-state"><h3>No reports to review.</h3><p>Submitted trail problems will appear here. Try another filter or trail.</p></div>}
        {rows.map(report => <button key={report.id} className={`report-list-card ${selected === report.id ? 'selected' : ''}`} aria-pressed={selected === report.id} onClick={() => choose(report.id)}>
          <span className="report-card-meta"><span className={`report-status status-${report.status}`}>{reportStatusLabels[report.status] || report.status}</span><span>{report.receivedAt?.toDate().toLocaleDateString()}</span></span>
          <strong>{reportCategories[report.category] || report.category}</strong><p>{report.description}</p><span className="report-card-meta"><span>{report.passability} · {report.priority}</span><span>{report.photos.length} photos</span></span>
        </button>)}
        {rows.length >= count && <button className="button button-secondary" onClick={() => setCount(n => n + 50)}>Load older reports</button>}
      </section><section id="selected-trail-report" className="report-detail-slot" aria-label="Selected report">
        {current ? <ReportDetail key={current.id} report={current} trailName={trailName} onReviewSaved={setReviewMessage} /> : <div className="empty-state report-placeholder"><span aria-hidden="true">↗</span><h3>Select a report</h3><p>Open a problem to see its location, photos and review history.</p></div>}
      </section></div>
    </>}
    {access?.admin && <AccessManager trails={access.trails} />}
  </div></main>;
}
function ReportDetail({report, trailName, onReviewSaved}: {report: TrailReport; trailName: string; onReviewSaved: (message: string) => void}) {
  const [photos, setPhotos] = useState<Record<string, string>>({}), [events, setEvents] = useState<ReportEvent[]>([]);
  const [error, setError] = useState(''), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const [photoView, setPhotoView] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    void Promise.all(report.photos.map(async p => [p.id, await reportPhoto(report.id, p.id, true)] as const))
      .then(items => {if (alive) setPhotos(Object.fromEntries(items));}).catch(() => {if (alive) setError('Photos could not be loaded.');});
    const stop = watchReportEvents(report.id, items => {if (alive) setEvents(items);}, () => {if (alive) {setEvents([]); setPhotos({}); setPhotoView(null); setError('Report access is no longer available.');}});
    return () => {alive = false; stop();};
  }, [report.id, report.photos]);
  async function act(task: () => Promise<void>) {
    setBusy(true); setError(''); setMessage('');
    try {await task();} catch (e) {setError(e instanceof Error ? e.message : 'The action failed. Please retry.');} finally {setBusy(false);}
  }
  async function exportReport() {
    const images = await Promise.all(report.photos.map(p => reportPhoto(report.id, p.id, false)));
    downloadFile(`EuroTrex-${report.id}.html`, reportPrintHtml(report, trailName, images), 'text/html');
    setMessage('Open the downloaded report and select Print / Save as PDF.');
  }
  return <article className="report-detail">
    <p className="eyebrow">{trailName}</p><h2>{reportCategories[report.category] || report.category}</h2><p className="report-description">{report.description}</p>
    <ReportProgress report={report} events={events} />
    <dl className="report-facts"><div><dt>Reference</dt><dd>{report.id}</dd></div><div><dt>Coordinates</dt><dd>{report.latitude.toFixed(6)}, {report.longitude.toFixed(6)}</dd></div><div><dt>Location source</dt><dd>{report.locationSource}{report.accuracyM != null ? ` · ±${Math.round(report.accuracyM)} m` : ''}</dd></div><div><dt>Stage context</dt><dd>{report.stageId || 'Not assigned'}</dd></div><div><dt>Observed</dt><dd>{new Date(report.observedAtMs).toLocaleString()}</dd></div><div><dt>Trail access</dt><dd>{report.passability}</dd></div><div><dt>Contact (private)</dt><dd>{report.contactEmail || 'Not provided'}</dd></div></dl>
    <div className="report-location-actions" aria-label="Report actions"><a href={reportMapUrl(report)} target="_blank" rel="noreferrer" className="button button-secondary"><img src="/icons/google-maps.ico" width="20" height="20" alt="" />Google Maps</a><a href={reportMapyUrl(report)} target="_blank" rel="noreferrer" className="button button-secondary"><img src="/icons/mapy.png" width="20" height="20" alt="" />Mapy</a><button className="button button-secondary" disabled={busy} onClick={() => void act(exportReport)}>Download printable report</button></div>
    <div className="report-photos">{report.photos.map(p => <button key={p.id} disabled={busy} onClick={() => void act(async () => setPhotoView(await reportPhoto(report.id, p.id, false)))} aria-label="Open full report photo">{photos[p.id] ? <img src={photos[p.id]} alt="Trail problem reported by a hiker" /> : <span>Loading photo…</span>}</button>)}</div>
    {photoView && <dialog open className="report-photo-view"><button className="button button-secondary" onClick={() => setPhotoView(null)}>Close photo</button><img src={photoView} alt="Full report photo" /></dialog>}
    <p className="report-helper">The printable report includes photos and excludes the reporter’s email and internal notes.</p>
    <ReportReview report={report} onSaved={onReviewSaved} />
    {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
    <h3>Activity</h3><ol className="report-history">{events.map(event => <li key={event.id}><strong>{event.previousStatus && event.status && event.previousStatus !== event.status ? `${reportStatusLabels[event.previousStatus] || event.previousStatus} → ${reportStatusLabels[event.status] || event.status}` : event.action === 'review' ? `Details updated · ${reportStatusLabels[event.status || ''] || event.status}` : 'Report received'}</strong><span>{event.createdAt?.toDate().toLocaleString()} · {event.actorEmail || 'Reporter'}</span>{event.note && <p>{event.note}</p>}{event.authority && <p>Authority: {event.authority} {event.forwardingReference}</p>}</li>)}</ol>
  </article>;
}
function AccessManager({trails}: {trails: Trail[]}) {
  const [members, setMembers] = useState<{id: string; email: string; trailIds: string[]}[]>([]);
  const [email, setEmail] = useState(''), [trailId, setTrailId] = useState(trails[0]?.id || '');
  const [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  useEffect(() => onSnapshot(collection(db, 'trailReportAccess'), snapshot => setMembers(snapshot.docs.map(d => ({id: d.id, ...d.data()}) as {id: string; email: string; trailIds: string[]})), () => {setMembers([]); setMessage('Could not load trail assignments.');}), []);
  async function change(mail: string, trail: string, grant: boolean) {
    setBusy(true); setMessage(''); try {await setReportAccess(mail, trail, grant); setMessage(grant ? 'Trail access granted.' : 'Trail access removed.');} catch (e) {setMessage(e instanceof Error ? e.message : 'Could not update access.');} finally {setBusy(false);}
  }
  return <section className="form-panel report-access"><p className="eyebrow">ADMIN ONLY</p><h2>Trail team access</h2><p>Ask the user to create an account on this page and verify their email first. Assign only the trails they should review. Removing access also removes access to report photos. While this website is private, users also need an invitation through the website sharing settings.</p>
    <form className="form-grid report-access-form" onSubmit={e => {e.preventDefault(); void change(email, trailId, true);}}><label>Verified account email<input type="email" required value={email} onChange={e => setEmail(e.target.value)} /></label><ReportSelect label="Trail" value={trailId} onChange={setTrailId} options={trails.map(t => ({value: t.id, label: t.name}))} /><button disabled={busy || !trailId} className="button button-primary">Grant access</button></form>
    {message && <p role="status">{message}</p>}
    <ul className="report-members">{members.flatMap(member => member.trailIds.map(id => <li key={`${member.id}:${id}`}><span><strong>{member.email}</strong><br />{trails.find(t => t.id === id)?.name || id}</span><button className="button button-secondary" disabled={busy} onClick={() => {if (window.confirm(`Remove ${member.email} from this trail?`)) void change(member.email, id, false);}}>Remove access</button></li>))}</ul>
  </section>;
}
