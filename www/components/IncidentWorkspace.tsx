'use client';
import {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import type {User} from 'firebase/auth';
import {collection, onSnapshot} from 'firebase/firestore';
import {AccountVerificationGate} from '@/components/AccountVerificationGate';
import {AuthPanel} from '@/components/AuthPanel';
import {PortalHeader} from '@/components/PortalHeader';
import {ReportSelect} from '@/components/ReportSelect';
import {ReportStatusIcon} from '@/components/ReportStatusIcon';
import {ReportProblemIcon} from '@/components/ReportProblemIcon';
import {OpeningTrailManagement} from '@/components/OpeningTrailManagement';
import {incidentSearchText} from '@/lib/incident-search';
import {matchesFuzzySearch} from '@/lib/fuzzy-search';
import {ReportDatePicker} from '@/components/ReportDatePicker';
import {TrailReportMap} from '@/components/TrailReportMap';
import {EraIncidentForm} from '@/components/EraIncidentForm';
import {ReportReview, reportStatusLabels} from '@/components/ReportReview';
import {preloadTrailRoutes} from '@/lib/trail-route';
import {watchReportAccess, reportLoadError, type AccessState, type ReportAccess} from '@/lib/report-access';
import {useAuthState} from '@/lib/use-auth';
import {db} from '@/lib/firebase';
import {watchTrailReports, watchReportEvents, reportCategories, reportStatuses, reportPhoto,
  setReportAccess, reportMapUrl, reportMapyUrl, reportPrintHtml, downloadFile,
  type TrailReport, type ReportEvent, type Trail} from '@/lib/trail-reports';

export default function TrailReportsPage() {
  const {user, loading} = useAuthState();
  if (loading) return <div className="loading-screen">Opening trail reports…</div>;
  if (!user) return <main className="portal-page trail-reports-page"><PortalHeader /><AuthPanel trailReports /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} />;
  return <ReportWorkspace key={user.uid} user={user} />;
}
export function ReportWorkspace({user, embeddedAccess, initialTrailId}: {user: User; embeddedAccess?: ReportAccess; initialTrailId?: string}) {
  const [accessState, setAccessState] = useState<AccessState>({status: 'loading'});
  const [attempt, setAttempt] = useState(0);
  const access = accessState.status === 'ready' ? accessState.access : null;
  const [trailId, setTrailId] = useState(initialTrailId || '');
  const [reviewMessage, setReviewMessage] = useState('');
  const [status, setStatus] = useState(''), [category, setCategory] = useState(''), [fromDate, setFromDate] = useState('');
  const [count, setCount] = useState(50), [rows, setRows] = useState<TrailReport[]>([]);
  const [selected, setSelected] = useState(''), [creatingIncident, setCreatingIncident] = useState(false);
  const [error, setError] = useState(''), [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const searchInput = useRef<HTMLInputElement>(null);
  const [settledTrail, setSettledTrail] = useState(''), [openedTrail, setOpenedTrail] = useState('');
  const mapSettled = useCallback(() => setSettledTrail(trailId), [trailId]);
  const indexed = useMemo(() => rows.map(report => ({report, text: incidentSearchText(report, reportCategories[report.category] || report.category, reportStatusLabels[report.status] || report.status)})), [rows]);
  const filteredRows = useMemo(() => indexed.filter(item => matchesFuzzySearch(item.text, search)).map(item => item.report), [indexed, search]);
  const opening = !!embeddedAccess && openedTrail !== trailId;
  useEffect(() => {
    if (access && settledTrail === trailId && (!loading || error)) setOpenedTrail(trailId);
  }, [access, settledTrail, trailId, loading, error]);
  useEffect(() => setSearch(''), [trailId]);
  const workspace = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const root = workspace.current, card = root?.querySelector<HTMLElement>('.report-list-card.selected'), pane = root?.querySelector<HTMLElement>('.report-detail-slot');
    if (!card || !pane || !root) return;
    // Connect the full card height, clipping the join when the list is longer than the pane.
    const updateJoin = () => {
      const tab = card.getBoundingClientRect(), detail = pane.getBoundingClientRect();
      const top = Math.max(-1, detail.top - tab.top - 1), bottom = Math.max(-1, tab.bottom - detail.bottom - 1);
      card.style.setProperty('--incident-join-top', `${top}px`);
      card.style.setProperty('--incident-join-bottom', `${bottom}px`);
      card.dataset.connected = String(tab.height > top + bottom);
    };
    const observer = new ResizeObserver(updateJoin);
    observer.observe(root); observer.observe(pane); observer.observe(card);
    updateJoin();
    return () => observer.disconnect();
  }, [selected, filteredRows, opening]);
  useEffect(() => {
    if (embeddedAccess) {setAccessState({status: 'ready', access: embeddedAccess}); return;}
    return watchReportAccess(user, state => {
    setAccessState(state);
    if (state.status === 'ready') {
      setTrailId(current => state.access.trails.some(t => t.id === current) ? current : state.access.trails[0]?.id || '');
    } else {setRows([]); setSelected(''); setError('');}
  });}, [user, attempt, embeddedAccess]);
  // Warm other assigned trail routes after the visible map and report list start.
  useEffect(() => {
    if (!access || !trailId || loading || error) return;
    const timer = window.setTimeout(() => {
      preloadTrailRoutes([trailId, ...access.trails.map(t => t.id).filter(id => id !== trailId)]);
    }, 300);
    return () => window.clearTimeout(timer);
  }, [access, loading, error, trailId]);
  useEffect(() => {
    setRows([]); setSelected(''); setCount(50);
  }, [trailId, status, category, fromDate]);
  useEffect(() => {
    if (!access || !trailId || !access.trails.some(t => t.id === trailId)) {setRows([]); setLoading(false); return;}
    setLoading(true); setError('');
    const timer = window.setTimeout(() => {
      setLoading(false); setError('Connecting to reports is taking too long. Check your connection and try again.');
    }, 12000);
    const stop = watchTrailReports(trailId, status, category, count, fromDate, reports => {
      window.clearTimeout(timer); setError(''); setRows(reports); setLoading(false);
      setSelected(current => reports.some(r => r.id === current) ? current : '');
    }, cause => {
      window.clearTimeout(timer); setRows([]); setSelected(''); setLoading(false);
      setError(reportLoadError(cause, 'reports'));
    });
    return () => {window.clearTimeout(timer); stop();};
  }, [access, trailId, status, category, count, fromDate]);

  const choose = useCallback((id: string) => setSelected(id), []);
  const current = filteredRows.find(row => row.id === selected);
  const trailName = access?.trails.find(t => t.id === trailId)?.name || trailId;
  return <main className="portal-page trail-reports-page">{!embeddedAccess && <PortalHeader user={user} canAccessAdmin={access?.admin} />}<div className="dashboard-shell wide">
    {!embeddedAccess && <section className="dashboard-title"><div><p className="eyebrow">TRAIL CARE</p><h1>Trail reports.</h1><p>Review problems, coordinate repairs and keep a record of what happens next.</p></div>{access && <span className="admin-badge">{access.admin ? 'Admin' : 'Trail team'}</span>}</section>}
    {(error || accessState.status === 'error') && <section className="notice error" role="alert"><p>{accessState.status === 'error' ? accessState.message : error}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Try again</button></section>}
    {!access ? (accessState.status === 'loading' ? (embeddedAccess ? <OpeningTrailManagement/> : <p role="status">Checking your assigned trails…</p>) : null) : !access.trails.length ? <section className="access-card"><h2>No trails assigned yet.</h2><p>Your email is verified. Ask a EuroTrex administrator to grant trail access to {user.email}.</p></section> : <div className={`report-opening-shell${opening ? ' is-opening' : ''}`}>
      {opening && <OpeningTrailManagement/>}
      <div className="report-loaded-content" aria-hidden={opening || undefined} inert={opening}>
      <section className="form-panel form-grid report-filters" aria-label="Filter reports">
        {!embeddedAccess && <ReportSelect label="Trail" value={trailId} onChange={setTrailId} options={access.trails.map(t => ({value: t.id, label: t.name}))} />}
        <ReportSelect hideLabel={!!embeddedAccess} className={`report-status-select${status?` status-${status}`:''}`} label="Status" value={status} onChange={setStatus} options={[{value: '', label: 'All', indicator: <ReportStatusIcon status=""/>}, ...reportStatuses.map(s => ({value: s, label: reportStatusLabels[s], indicator: <ReportStatusIcon status={s}/>}))]} />
        <ReportSelect hideLabel={!!embeddedAccess} label="Problem" value={category} onChange={setCategory} options={[{value: '', label: 'All problems'}, ...Object.entries(reportCategories).map(([value, label]) => ({value, label, indicator: <ReportProblemIcon category={value}/>}))]} />
        <ReportDatePicker hideLabel={!!embeddedAccess} value={fromDate} onChange={setFromDate} />
        {embeddedAccess && <div className="era-filter-action"><button type="button" className="era-icon-button" aria-label={creatingIncident ? 'Close incident form' : 'Create incident'} title={creatingIncident ? 'Close incident form' : 'Create incident'} aria-expanded={creatingIncident} aria-controls="era-incident-form" onClick={() => setCreatingIncident(open => !open)}><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d={creatingIncident ? 'm6 6 12 12M6 18 18 6' : 'M12 5v14M5 12h14'}/></svg></button></div>}
      </section>
      {embeddedAccess && <EraIncidentForm trailId={trailId} open={creatingIncident} onClose={() => setCreatingIncident(false)} />}
      {trailId && <TrailReportMap visible key={trailId} trailId={trailId} trailName={trailName} reports={filteredRows} selectedId={current?.id || ''} onSelect={choose} onSettled={mapSettled} />}
      {reviewMessage && <p className="notice" role="status">{reviewMessage}</p>}
      <div className="report-search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg><input ref={searchInput} type="search" aria-label="Search reports" placeholder="Search reports…" value={search} onChange={event => setSearch(event.target.value)}/>
        <span className="report-search-count" role="status" title="Loaded reports · newest first">{loading ? 'Loading…' : error ? 'Unavailable' : search.trim() ? `${filteredRows.length} / ${rows.length} reports` : `${rows.length} reports loaded`}</span>
        {search && <button type="button" aria-label="Clear report search" onClick={() => {setSearch(''); searchInput.current?.focus();}}>×</button>}
      </div>
      <div ref={workspace} className="report-workspace"><section className="report-inbox" aria-label="Reports">
        {!loading && !error && !rows.length && <div className="empty-state report-empty-state"><h3>No reports to review.</h3><p>Submitted trail problems will appear here. Try another filter or trail.</p></div>}
        {!loading && !error && !!rows.length && !filteredRows.length && <div className="empty-state report-empty-state"><h3>No matching reports.</h3></div>}
        {filteredRows.map(report => <button key={report.id} className={`report-list-card ${selected === report.id ? 'selected' : ''}`} aria-pressed={selected === report.id} onClick={() => choose(report.id)}>
          <span className="report-card-meta"><span className={`report-status status-${report.status}`}>{reportStatusLabels[report.status] || report.status}</span><span>{report.receivedAt?.toDate().toLocaleDateString()}</span></span>
          <div className="report-card-heading"><strong>{reportCategories[report.category] || report.category}</strong><small>{report.origin === 'organisation' ? 'Organisation-created' : 'Hiker report'}</small></div><p>{report.description}</p><span className="report-card-meta"><span>{report.passability} · {report.priority}</span><span>{report.photos.length} photos</span></span>
        </button>)}
        {rows.length >= count && <button className="button button-secondary" onClick={() => setCount(n => n + 50)}>Load older reports</button>}
      </section><section id="selected-trail-report" className="report-detail-slot" aria-label="Selected report">
        {current ? <ReportDetail compact={!!embeddedAccess} key={current.id} report={current} trailName={trailName} onReviewSaved={setReviewMessage} /> : <div className="empty-state report-placeholder"><span aria-hidden="true">↗</span><h3>Select a report</h3><p>Open a problem to see its location, photos and review history.</p></div>}
      </section></div>
    </div></div>}
    {!embeddedAccess && access?.admin && <AccessManager trails={access.trails} />}
  </div></main>;
}
function ReportDetail({report, trailName, onReviewSaved, compact = false}: {compact?: boolean; report: TrailReport; trailName: string; onReviewSaved: (message: string) => void}) {
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
    {!compact && <><p className="eyebrow">{trailName}</p><h2>{reportCategories[report.category] || report.category}</h2><p className="report-description">{report.description}</p>
    <p className="report-helper">{report.origin === 'organisation' ? 'Organisation-created incident' : 'Hiker report'} · Route release: {report.routeReleaseId || 'Legacy route'}</p></>}
    <dl className="report-facts"><div><dt>Reference</dt><dd>{report.id}</dd></div><div><dt>Coordinates</dt><dd className="report-coordinates"><span>{report.latitude.toFixed(6)}, {report.longitude.toFixed(6)}</span><span className="report-coordinate-links"><a href={reportMapUrl(report)} target="_blank" rel="noreferrer" aria-label="Open coordinates in Google Maps" title="Open in Google Maps"><img src="/icons/google-maps.ico" width="20" height="20" alt="" /></a><a href={reportMapyUrl(report)} target="_blank" rel="noreferrer" aria-label="Open coordinates in Mapy" title="Open in Mapy"><img src="/icons/mapy.png" width="20" height="20" alt="" /></a></span></dd></div><div><dt>Location source</dt><dd>{report.locationSource}{report.accuracyM != null ? ` · ±${Math.round(report.accuracyM)} m` : ''}</dd></div><div><dt>Stage context</dt><dd>{report.stageId || 'Not assigned'}</dd></div><div><dt>Observed</dt><dd>{new Date(report.observedAtMs).toLocaleString()}</dd></div><div><dt>Trail access</dt><dd>{report.passability}</dd></div><div><dt>Contact (private)</dt><dd>{report.contactEmail || 'Not provided'}</dd></div></dl>
    <div className="report-photos">{report.photos.map(p => <button key={p.id} disabled={busy} onClick={() => void act(async () => setPhotoView(await reportPhoto(report.id, p.id, false)))} aria-label="Open full report photo">{photos[p.id] ? <img src={photos[p.id]} alt="Trail problem reported by a hiker" /> : <span>Loading photo…</span>}</button>)}</div>
    {photoView && <dialog open className="report-photo-view"><button type="button" className="notify-dialog-close" aria-label="Close photo" onClick={() => setPhotoView(null)}>×</button><img src={photoView} alt="Full report photo" /></dialog>}
    <div className="report-print-action"><button className="button button-secondary" disabled={busy} onClick={() => void act(exportReport)}><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4"/></svg>Report</button><p className="report-helper">The report includes photos and excludes the reporter’s email and internal notes.</p></div>
    <ReportReview report={report} onSaved={onReviewSaved} />
    {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
    <details className="report-activity"><summary>Activity<span className="report-activity-toggle" aria-hidden="true"/></summary>{!events.length && <p className="report-helper">No activity recorded yet.</p>}<ol className="report-history">{events.map(event => <li key={event.id}><strong>{event.previousStatus && event.status && event.previousStatus !== event.status ? `${reportStatusLabels[event.previousStatus] || event.previousStatus} → ${reportStatusLabels[event.status] || event.status}` : event.action === 'review' ? `Details updated · ${reportStatusLabels[event.status || ''] || event.status}` : 'Report received'}</strong><span>{event.createdAt?.toDate().toLocaleString()} · {event.actorEmail || 'Reporter'}</span>{event.note && <p>{event.note}</p>}{event.authority && <p>Authority: {event.authority} {event.forwardingReference}</p>}</li>)}</ol></details>
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
