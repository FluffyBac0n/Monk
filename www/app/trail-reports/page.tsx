'use client';
import {useCallback, useEffect, useState} from 'react';
import type {User} from 'firebase/auth';
import {collection, doc, onSnapshot} from 'firebase/firestore';
import {AccountVerificationGate} from '@/components/AccountVerificationGate';
import {AuthPanel} from '@/components/AuthPanel';
import {PortalHeader} from '@/components/PortalHeader';
import {TrailReportMap} from '@/components/TrailReportMap';
import {useAuthState} from '@/lib/use-auth';
import {db} from '@/lib/firebase';
import {reportAccess, watchTrailReports, watchReportEvents, reportCategories, reportStatuses, reportPhoto,
  reviewReport, setReportAccess, reportMapUrl, forwardingText, reportPrintHtml, reportEmail, downloadFile,
  type TrailReport, type ReportEvent, type Trail} from '@/lib/trail-reports';

export default function TrailReportsPage() {
  const {user, loading} = useAuthState();
  if (loading) return <div className="loading-screen">Opening trail reports…</div>;
  if (!user) return <main className="portal-page trail-reports-page"><PortalHeader /><AuthPanel trailReports /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} />;
  return <ReportWorkspace key={user.uid} user={user} />;
}
function ReportWorkspace({user}: {user: User}) {
  const [access, setAccess] = useState<{admin: boolean; trails: Trail[]} | null>(null);
  const [trailId, setTrailId] = useState('');
  const [status, setStatus] = useState(''), [category, setCategory] = useState(''), [fromDate, setFromDate] = useState('');
  const [count, setCount] = useState(50), [rows, setRows] = useState<TrailReport[]>([]);
  const [selected, setSelected] = useState(''), [mapView, setMapView] = useState(false);
  const [error, setError] = useState(''), [loading, setLoading] = useState(true);
  useEffect(() => {
    let alive = true;
    const refresh = () => reportAccess(user).then(result => {
      if (!alive) return;
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
        <label>Trail<select value={trailId} onChange={e => setTrailId(e.target.value)}>{access.trails.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}</select></label>
        <label>Status<select value={status} onChange={e => setStatus(e.target.value)}><option value="">All statuses</option>{reportStatuses.map(s => <option key={s}>{s}</option>)}</select></label>
        <label>Problem<select value={category} onChange={e => setCategory(e.target.value)}><option value="">All problems</option>{Object.entries(reportCategories).map(([value, name]) => <option key={value} value={value}>{name}</option>)}</select></label>
        <label>Received since<input type="date" value={fromDate} onChange={e => setFromDate(e.target.value)} /></label>
        <button className="button button-secondary" aria-pressed={mapView} onClick={() => setMapView(v => !v)}>{mapView ? 'Hide map' : 'Show map'}</button>
      </section>
      {mapView && <TrailReportMap reports={rows} onSelect={choose} />}
      <p className="report-list-caption" role="status">{loading ? 'Loading reports…' : `${rows.length} reports loaded · newest first`}</p>
      <div className="report-workspace"><section className="report-inbox" aria-label="Reports">
        {!loading && !rows.length && <div className="empty-state report-empty-state"><h3>No reports to review.</h3><p>Submitted trail problems will appear here. Try another filter or trail.</p></div>}
        {rows.map(report => <button key={report.id} className={`report-list-card ${selected === report.id ? 'selected' : ''}`} aria-pressed={selected === report.id} onClick={() => setSelected(report.id)}>
          <span className="report-card-meta"><span className={`report-status status-${report.status}`}>{report.status}</span><span>{report.receivedAt?.toDate().toLocaleDateString()}</span></span>
          <strong>{reportCategories[report.category] || report.category}</strong><p>{report.description}</p><span className="report-card-meta"><span>{report.passability} · {report.priority}</span><span>{report.photos.length} photos</span></span>
        </button>)}
        {rows.length >= count && <button className="button button-secondary" onClick={() => setCount(n => n + 50)}>Load older reports</button>}
      </section><section className="report-detail-slot" aria-label="Selected report">
        {current ? <ReportDetail key={current.id} report={current} trailName={trailName} /> : <div className="empty-state report-placeholder"><span aria-hidden="true">↗</span><h3>Select a report</h3><p>Open a problem to see its location, photos and review history.</p></div>}
      </section></div>
    </>}
    {access?.admin && <AccessManager trails={access.trails} />}
  </div></main>;
}
function ReportDetail({report, trailName}: {report: TrailReport; trailName: string}) {
  const [reviewBase, setReviewBase] = useState(report), [dirty, setDirty] = useState(false);
  const [photos, setPhotos] = useState<Record<string, string>>({}), [events, setEvents] = useState<ReportEvent[]>([]);
  const [status, setStatus] = useState(report.status), [priority, setPriority] = useState(report.priority);
  const [authority, setAuthority] = useState(report.authority), [reference, setReference] = useState(report.forwardingReference);
  const [duplicate, setDuplicate] = useState(report.duplicateOf || ''), [note, setNote] = useState('');
  const [error, setError] = useState(''), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const [photoView, setPhotoView] = useState<string | null>(null);
  useEffect(() => {
    if (dirty) return;
    setReviewBase(report); setStatus(report.status); setPriority(report.priority);
    setAuthority(report.authority); setReference(report.forwardingReference); setDuplicate(report.duplicateOf || '');
  }, [report, dirty]);
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
  async function exportReport(email: boolean) {
    const images = await Promise.all(report.photos.map(p => reportPhoto(report.id, p.id, false)));
    if (email) downloadFile(`EuroTrex-${report.id}.eml`, reportEmail(report, trailName, images), 'message/rfc822');
    else {
      const html = reportPrintHtml(report, trailName, images);
      downloadFile(`EuroTrex-${report.id}.html`, html, 'text/html');
      setMessage('Open the downloaded report and select Print / Save as PDF.');
    }
  }
  return <article className="report-detail">
    <p className="eyebrow">{trailName}</p><h2>{reportCategories[report.category] || report.category}</h2><p className="report-description">{report.description}</p>
    <dl className="report-facts"><div><dt>Reference</dt><dd>{report.id}</dd></div><div><dt>Coordinates</dt><dd>{report.latitude.toFixed(6)}, {report.longitude.toFixed(6)}</dd></div><div><dt>Location source</dt><dd>{report.locationSource}{report.accuracyM != null ? ` · ±${Math.round(report.accuracyM)} m` : ''}</dd></div><div><dt>Stage context</dt><dd>{report.stageId || 'Not assigned'}</dd></div><div><dt>Observed</dt><dd>{new Date(report.observedAtMs).toLocaleString()}</dd></div><div><dt>Trail access</dt><dd>{report.passability}</dd></div><div><dt>Contact (private)</dt><dd>{report.contactEmail || 'Not provided'}</dd></div></dl>
    <a href={reportMapUrl(report)} target="_blank" rel="noreferrer" className="button button-secondary">Open in Google Maps ↗</a>
    <div className="report-photos">{report.photos.map(p => <button key={p.id} disabled={busy} onClick={() => void act(async () => setPhotoView(await reportPhoto(report.id, p.id, false)))} aria-label="Open full report photo">{photos[p.id] ? <img src={photos[p.id]} alt="Trail problem reported by a hiker" /> : <span>Loading photo…</span>}</button>)}</div>
    {photoView && <dialog open className="report-photo-view"><button className="button button-secondary" onClick={() => setPhotoView(null)}>Close photo</button><img src={photoView} alt="Full report photo" /></dialog>}
    <div className="report-export-actions"><button className="button button-secondary" disabled={busy} onClick={() => void act(() => exportReport(false))}>Download printable report</button><button className="button button-secondary" disabled={busy} onClick={() => void act(() => exportReport(true))}>Download email with photos</button><button className="button button-secondary" disabled={busy} onClick={() => void act(async () => {await navigator.clipboard.writeText(forwardingText(report, trailName)); setMessage('Forwarding text copied.');})}>Copy forwarding text</button></div>
    <p className="report-helper">Exports exclude the reporter’s email and internal notes. Record forwarding below after sending it to the authority.</p>
    {dirty && reviewBase.updatedAt.toMillis() !== report.updatedAt.toMillis() && <p className="notice" role="alert">Another reviewer updated this report. Your notes are preserved; copy them before reopening the report to load the latest review.</p>}
    <form className="form-grid single report-review" onChange={() => setDirty(true)} onSubmit={e => {e.preventDefault(); void act(async () => {await reviewReport(reviewBase, {status, priority, authority, forwardingReference: reference, duplicateOf: duplicate, note}); setNote(''); setDirty(false); setMessage('Review saved.');});}}>
      <h3>Review and follow-up</h3><div className="report-review-row"><label>Status<select value={status} onChange={e => setStatus(e.target.value)}>{reportStatuses.map(s => <option key={s}>{s}</option>)}</select></label><label>Priority<select value={priority} onChange={e => setPriority(e.target.value)}>{['normal','high','urgent'].map(s => <option key={s}>{s}</option>)}</select></label></div>
      <label>Responsible authority / recipient<input value={authority} maxLength={200} required={status === 'forwarded'} onChange={e => setAuthority(e.target.value)} /></label>
      <label>Forwarding reference<input value={reference} maxLength={300} onChange={e => setReference(e.target.value)} placeholder="Email recipient, date or case reference" /></label>
      {status === 'duplicate' && <label>Original report ID<input value={duplicate} required onChange={e => setDuplicate(e.target.value)} /></label>}
      <label>Internal note<textarea value={note} maxLength={1500} required={['resolved','dismissed'].includes(status)} rows={3} onChange={e => setNote(e.target.value)} placeholder="Review notes, forwarding details or resolution" /></label>
      <button className="button button-primary" disabled={busy}>{busy ? 'Saving…' : 'Save review'}</button>
    </form>
    {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
    <h3>Activity</h3><ol className="report-history">{events.map(event => <li key={event.id}><strong>{event.status || event.action}</strong><span>{event.createdAt?.toDate().toLocaleString()} · {event.actorEmail || 'Reporter'}</span>{event.note && <p>{event.note}</p>}{event.authority && <p>Authority: {event.authority} {event.forwardingReference}</p>}</li>)}</ol>
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
    <form className="form-grid report-access-form" onSubmit={e => {e.preventDefault(); void change(email, trailId, true);}}><label>Verified account email<input type="email" required value={email} onChange={e => setEmail(e.target.value)} /></label><label>Trail<select value={trailId} onChange={e => setTrailId(e.target.value)}>{trails.map(t => <option key={t.id} value={t.id}>{t.name}</option>)}</select></label><button disabled={busy || !trailId} className="button button-primary">Grant access</button></form>
    {message && <p role="status">{message}</p>}
    <ul className="report-members">{members.flatMap(member => member.trailIds.map(id => <li key={`${member.id}:${id}`}><span><strong>{member.email}</strong><br />{trails.find(t => t.id === id)?.name || id}</span><button className="button button-secondary" disabled={busy} onClick={() => {if (window.confirm(`Remove ${member.email} from this trail?`)) void change(member.email, id, false);}}>Remove access</button></li>))}</ul>
  </section>;
}
