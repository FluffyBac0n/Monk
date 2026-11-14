'use client';
import {useCallback, useEffect, useMemo, useRef, useState} from 'react';
import type {User} from 'firebase/auth';
import {collection, doc, onSnapshot} from 'firebase/firestore';
import {IncidentDrafts} from '@/components/IncidentDrafts';
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
import {ReportActivityDialog} from '@/components/ReportActivityDialog';
import {ReportReview, reportStatusLabels} from '@/components/ReportReview';
import {preloadTrailRoutes} from '@/lib/trail-route';
import {watchReportAccess, reportLoadError, type AccessState, type ReportAccess} from '@/lib/report-access';
import {useAuthState} from '@/lib/use-auth';
import {db} from '@/lib/firebase';
import {eraCall} from '@/lib/era';
import {watchTrailReports, watchReportEvents, reportCategories, reportStatuses, reportPhoto,
  setReportAccess, reportMapUrl, reportMapyUrl, reportPrintHtml, downloadFile,
  type TrailReport, type ReportEvent, type Trail} from '@/lib/trail-reports';

export default function TrailReportsPage() {
  const {user, loading} = useAuthState();
  if (loading) return <div className="loading-screen">Opening trail reports…</div>;
  if (!user) return <main className="portal-page trail-reports-page"><PortalHeader /><AuthPanel trailReports /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} />;
  return <IncidentDrafts key={user.uid}><ReportWorkspace user={user} /></IncidentDrafts>;
}
export function ReportWorkspace({user, embeddedAccess, initialTrailId}: {user: User; embeddedAccess?: ReportAccess; initialTrailId?: string}) {
  const [accessState, setAccessState] = useState<AccessState>({status: 'loading'});
  const [attempt, setAttempt] = useState(0);
  const access = accessState.status === 'ready' ? accessState.access : null;
  const [trailId, setTrailId] = useState(initialTrailId || '');
  const [reviewMessage, setReviewMessage] = useState('');
  useEffect(() => {if (!reviewMessage) return; const timer = window.setTimeout(() => setReviewMessage(''), 4500); return () => window.clearTimeout(timer);}, [reviewMessage]);
  const [status, setStatus] = useState(''), [category, setCategory] = useState(''), [fromDate, setFromDate] = useState('');
  const [listedRows, setRows] = useState<TrailReport[]>([]);
  const [page, setPage] = useState(0);
  const pageSize = 8;
  const [linkId, setLinkId] = useState(''), [linkedReport, setLinkedReport] = useState<TrailReport | null>(null), [linkError, setLinkError] = useState('');
  const linkSelected = useRef(false);
  const rows = useMemo(() => linkedReport && !listedRows.some(row => row.id === linkedReport.id) && (!status || status === linkedReport.status) && (!category || category === linkedReport.category) && (!fromDate || linkedReport.receivedAt.toMillis() >= new Date(fromDate).getTime()) ? [linkedReport, ...listedRows].sort((a,b) => b.receivedAt.toMillis() - a.receivedAt.toMillis()) : listedRows, [listedRows, linkedReport, status, category, fromDate]);
  const [referenceError, setReferenceError] = useState(''), [referenceAttempt, setReferenceAttempt] = useState(0);
  const missingReferences = rows.filter(row => !row.ticketReference).map(row => row.id).sort().join(',');
  useEffect(() => {
    if (!access || !missingReferences) return;
    let active = true;
    const ids = missingReferences.split(',');
    void (async () => {
      try {for(let start=0;start<ids.length;start+=50){if(!active)return;await eraCall('ensureIncidentReferences', {trailId, reportIds:ids.slice(start,start+50)});}if(active)setReferenceError('');}
      catch {if(active)setReferenceError('Ticket numbers could not be loaded.');}
    })();
    return () => {active = false;};
  }, [access, trailId, missingReferences, referenceAttempt]);
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
  const workspace = useRef<HTMLDivElement>(null), createButton = useRef<HTMLButtonElement>(null);
  useEffect(() => {
    if (!creatingIncident) return;
    const frame = requestAnimationFrame(() => {
      const form = document.getElementById('era-incident-form');
      form?.closest('section')?.scrollIntoView({block: 'start', behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth'});
      form?.querySelector<HTMLElement>('button, input, textarea')?.focus({preventScroll: true});
    });
    return () => cancelAnimationFrame(frame);
  }, [creatingIncident]);
  function closeIncidentForm() {setCreatingIncident(false); createButton.current?.focus({preventScroll: true});}

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
    setRows([]); setSelected(''); setPage(0);
  }, [trailId, status, category, fromDate]);
  useEffect(() => {
    if (!access || !trailId || !access.trails.some(t => t.id === trailId)) {setRows([]); setLoading(false); return;}
    setLoading(true); setError('');
    const timer = window.setTimeout(() => {
      setLoading(false); setError('Connecting to reports is taking too long. Check your connection and try again.');
    }, 12000);
    const stop = watchTrailReports(trailId, status, category, fromDate, reports => {
      window.clearTimeout(timer); setError(''); setRows(reports); setLoading(false);
      setSelected(current => current === linkId || reports.some(r => r.id === current) ? current : '');
    }, cause => {
      window.clearTimeout(timer); setRows([]); setSelected(''); setLoading(false);
      setError(reportLoadError(cause, 'reports'));
    });
    return () => {window.clearTimeout(timer); stop();};
  }, [access, trailId, status, category, fromDate, linkId]);

  const pageCount = Math.max(1, Math.ceil(filteredRows.length / pageSize));
  const activePage = Math.min(page, pageCount - 1);
  const pageRows = filteredRows.slice(activePage * pageSize, (activePage + 1) * pageSize);
  const [revealId, setRevealId] = useState('');
  const chooseFromMap = useCallback((id: string) => {setSelected(id); setRevealId(id);}, []);
  function choose(id: string) {setSelected(current => current === id ? '' : id);}
  useEffect(() => {setPage(0);}, [search]);
  useEffect(() => {
    if (!revealId || opening) return;
    const index = filteredRows.findIndex(report => report.id === revealId);
    if (index < 0) return;
    const targetPage = Math.floor(index / pageSize);
    if (activePage !== targetPage) {setPage(targetPage);return;}
    const frame = requestAnimationFrame(() => {
      const row = workspace.current?.querySelector<HTMLElement>('.incident-row[aria-expanded="true"]');
      row?.scrollIntoView({block:'nearest', behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth'});
      row?.focus({preventScroll:true});
      setRevealId('');
    });
    return () => cancelAnimationFrame(frame);
  }, [revealId, opening, filteredRows, activePage]);
  function changePage(next: number) {setPage(next);setSelected('');}
  useEffect(() => {
    const query = new URLSearchParams(window.location.search), id = query.get('incident'), requestedTrail = query.get('trail');
    if (!embeddedAccess && requestedTrail) setTrailId(requestedTrail);
    if (id && /^[a-zA-Z0-9_-]{1,100}$/.test(id) && (!requestedTrail || requestedTrail === trailId)) setLinkId(id);
  }, [trailId, embeddedAccess]);
  useEffect(() => {
    if (!linkId || !access || !access.trails.some(trail => trail.id === trailId)) return;
    return onSnapshot(doc(db, 'trailReports', linkId), snapshot => {
      const report = snapshot.exists() ? {...snapshot.data(), id:snapshot.id} as TrailReport : null;
      if (!report || report.trailId !== trailId) {setLinkedReport(null);setLinkError('This incident is unavailable for this trail.');return;}
      setLinkedReport(report);setLinkError('');
      if (!linkSelected.current) {linkSelected.current = true;chooseFromMap(report.id);}
    }, () => {setLinkedReport(null);setLinkError('This incident is unavailable or you do not have access.');});
  }, [access, linkId, trailId, chooseFromMap]);
  const current = filteredRows.find(row => row.id === selected);
  const trailName = access?.trails.find(t => t.id === trailId)?.name || trailId;
  return <main className="portal-page trail-reports-page">{!embeddedAccess && <PortalHeader user={user} canAccessAdmin={access?.admin} />}<div className="dashboard-shell wide">
    {!embeddedAccess && <section className="dashboard-title"><div><p className="eyebrow">TRAIL CARE</p><h1>Trail reports.</h1><p>Review problems, coordinate repairs and keep a record of what happens next.</p></div>{access && <span className="admin-badge">{access.admin ? 'Admin' : 'Trail team'}</span>}</section>}
    {(error || accessState.status === 'error') && <section className="notice error" role="alert"><p>{accessState.status === 'error' ? accessState.message : error}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Try again</button></section>}
    {!access ? (accessState.status === 'loading' ? (embeddedAccess ? <OpeningTrailManagement/> : <p role="status">Checking your assigned trails…</p>) : null) : !access.trails.length ? <section className="access-card"><h2>No trails assigned yet.</h2><p>Your email is verified. Ask a EuroTrex administrator to grant trail access to {user.email}.</p></section> : <div className={`report-opening-shell${opening ? ' is-opening' : ''}`}>
      {opening && <OpeningTrailManagement/>}
      <div className="report-loaded-content" aria-hidden={opening || undefined} inert={opening}>
      {trailId && <TrailReportMap visible key={trailId} trailId={trailId} trailName={trailName} reports={filteredRows} selectedId={current?.id || ''} onSelect={chooseFromMap} onSettled={mapSettled} />}
      <div className="incident-search-controls">
      <div className="incident-search-toolbar" role="search" aria-label="Search and filter incidents">
      <div className="report-search"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg><input ref={searchInput} type="search" aria-label="Search reports" placeholder="Search reports…" value={search} onChange={event => setSearch(event.target.value)}/>
        <span className="report-search-count" role="status" title="Reports · newest first">{loading ? 'Loading…' : error ? 'Unavailable' : search.trim() ? `${filteredRows.length} / ${rows.length} reports` : `${rows.length} reports`}</span>
        {search && <button type="button" aria-label="Clear report search" onClick={() => {setSearch(''); searchInput.current?.focus();}}>×</button>}
      </div>
        <div className="incident-search-filters">
        {!embeddedAccess && <ReportSelect hideLabel label="Trail" value={trailId} onChange={setTrailId} options={access.trails.map(t => ({value: t.id, label: t.name}))} />}
        <ReportSelect hideLabel className={`report-status-select${status?` status-${status}`:''}`} label="Status" value={status} onChange={setStatus} options={[{value: '', label: 'All statuses', indicator: <ReportStatusIcon status=""/>}, ...reportStatuses.map(s => ({value: s, label: reportStatusLabels[s], indicator: <ReportStatusIcon status={s}/>}))]} />
        <ReportSelect hideLabel label="Problem" value={category} onChange={setCategory} options={[{value: '', label: 'All problems'}, ...Object.entries(reportCategories).map(([value, label]) => ({value, label, indicator: <ReportProblemIcon category={value}/>}))]} />
        <ReportDatePicker hideLabel value={fromDate} onChange={setFromDate} />
        </div>
      </div>
      {embeddedAccess && <button ref={createButton} type="button" className="button button-primary incident-create-inline" aria-label={creatingIncident ? 'Close incident form' : 'Create new incident'} title={creatingIncident ? 'Close incident form' : 'Create new incident'} aria-expanded={creatingIncident} aria-controls="era-incident-form" onClick={() => creatingIncident ? closeIncidentForm() : setCreatingIncident(true)}><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true"><path d={creatingIncident ? 'm6 6 12 12M6 18 18 6' : 'M12 5v14M5 12h14'}/></svg></button>}
      </div>
      {embeddedAccess && <EraIncidentForm key={trailId} trailId={trailId} open={creatingIncident} onClose={closeIncidentForm} />}
      {linkError && <p className="notice" role="alert">{linkError}</p>}
      {referenceError && <div className="notice" role="alert">{referenceError} <button type="button" className="text-button" onClick={() => setReferenceAttempt(value => value + 1)}>Retry</button></div>}
      {reviewMessage && <p className="report-save-toast" role="status">✓ {reviewMessage}</p>}
      <div ref={workspace} id="selected-trail-report" className="incident-list" aria-label="Reports">
        {!!filteredRows.length && <div className="incident-list-heading" aria-hidden="true"><span>Reference</span><span>Status</span><span>Problem</span><span>Description</span><span className="incident-heading-date">Received</span><span/></div>}
        {!loading && !error && !rows.length && <div className="empty-state report-empty-state"><h3>No reports to review.</h3></div>}
        {!loading && !error && !!rows.length && !filteredRows.length && <div className="empty-state report-empty-state"><h3>No matching reports.</h3></div>}
        {pageRows.map(report => <section key={report.id} className={`incident-item${current?.id === report.id ? ' is-expanded' : ''}`}>
          <button id={`incident-row-${report.id}`} className="incident-row" aria-expanded={current?.id === report.id} aria-controls={`incident-details-${report.id}`} onClick={() => choose(report.id)}>
            <span className="incident-row-reference">{report.ticketReference || 'Assigning reference…'}</span>
            <span className="incident-row-status" title={reportStatusLabels[report.status] || report.status}><ReportStatusIcon status={report.status}/><span>{reportStatusLabels[report.status] || report.status}</span></span>
            <span className="incident-row-problem"><ReportProblemIcon category={report.category}/><strong>{reportCategories[report.category] || report.category}</strong></span>
            <span className="incident-row-description">{report.description}</span>
            <time className="incident-row-date" dateTime={report.receivedAt?.toDate().toISOString()}>{report.receivedAt?.toDate().toLocaleDateString()}</time>
            <span className="incident-row-toggle" aria-hidden="true">{current?.id === report.id ? '−' : '+'}</span>
          </button>
          <div id={`incident-details-${report.id}`} role="region" aria-labelledby={`incident-row-${report.id}`} hidden={current?.id !== report.id}>{current?.id === report.id && <div><ReportDetail report={report} trailName={trailName} onReviewSaved={setReviewMessage}/></div>}</div>
        </section>)}
      </div>
      {filteredRows.length > pageSize && <nav className="incident-pagination" aria-label="Incident pages"><span role="status">{activePage * pageSize + 1}–{Math.min((activePage + 1) * pageSize, filteredRows.length)} of {filteredRows.length}</span><button type="button" className="button button-secondary" disabled={activePage === 0} onClick={() => changePage(activePage - 1)} aria-label="Previous page" title="Previous page"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m15 6-6 6 6 6"/></svg></button><span>{activePage + 1} / {pageCount}</span><button type="button" className="button button-secondary" disabled={activePage >= pageCount - 1} onClick={() => changePage(activePage + 1)} aria-label="Next page" title="Next page"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="m9 6 6 6-6 6"/></svg></button></nav>}
    </div></div>}
    {!embeddedAccess && access?.admin && <AccessManager trails={access.trails} />}
  </div></main>;
}
function ReportDetail({report, trailName, onReviewSaved}: { report: TrailReport; trailName: string; onReviewSaved: (message: string) => void}) {
  const [photos, setPhotos] = useState<Record<string, string>>({}), [events, setEvents] = useState<ReportEvent[]>([]);
  const [error, setError] = useState(''), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  const [copied, setCopied] = useState(false), [activityOpen, setActivityOpen] = useState(false);
  const [activityLoading, setActivityLoading] = useState(true), [activityError, setActivityError] = useState('');
  useEffect(() => {if (!copied) return; const timer = window.setTimeout(() => setCopied(false), 2000); return () => window.clearTimeout(timer);}, [copied]);
  async function copyLink() {
    try {const url = new URL('/era', window.location.origin);url.searchParams.set('trail', report.trailId);url.searchParams.set('incident', report.id);await navigator.clipboard.writeText(url.href);setCopied(true);}
    catch {setError('Could not copy the incident link. Please try again.');}
  }
  const [photoView, setPhotoView] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    const stop = watchReportEvents(report.id, items => {if (alive) {setEvents(items); setActivityLoading(false); setActivityError('');}}, () => {if (alive) {setEvents([]); setActivityLoading(false); setActivityError('Activity is unavailable. Check your access and reopen the incident.'); setPhotos({}); setPhotoView(null); setError('Report access is no longer available.');}});
    return () => {alive = false; stop();};
  }, [report.id]);
  useEffect(() => {
    let alive = true;
    void Promise.all(report.photos.map(async p => [p.id, await reportPhoto(report.id, p.id, true)] as const))
      .then(items => {if (alive) setPhotos(Object.fromEntries(items));}).catch(() => {if (alive) setError('Photos could not be loaded.');});
    return () => {alive = false;};
  }, [report.id, report.photos]);
  async function act(task: () => Promise<void>) {
    setBusy(true); setError(''); setMessage('');
    try {await task();} catch (e) {setError(e instanceof Error ? e.message : 'The action failed. Please retry.');} finally {setBusy(false);}
  }
  async function exportReport() {
    const images = await Promise.all(report.photos.map(p => reportPhoto(report.id, p.id, false)));
    downloadFile(`${report.ticketReference || report.id}.html`, reportPrintHtml(report, trailName, images), 'text/html');
    setMessage('Open the downloaded report and select Print / Save as PDF.');
  }
  return <article className="report-detail">
    <ReportReview report={report} onSaved={onReviewSaved} />
    <div className="incident-description"><p>{report.description}</p><div className="incident-detail-actions"><button type="button" className="report-copy-link" onClick={() => void copyLink()} aria-label={copied ? 'Link copied' : 'Copy incident link'} title={copied ? 'Link copied' : 'Copy incident link'}>{copied ? '✓' : <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" aria-hidden="true"><path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-2 2M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l2-2"/></svg>}</button><button type="button" className="report-copy-link" disabled={busy} onClick={() => void act(exportReport)} aria-label="Download report" title="Download report"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M12 3v12m-5-5 5 5 5-5M5 16v4h14v-4"/></svg></button><button type="button" className="report-copy-link" onClick={() => setActivityOpen(true)} aria-label="View activity log" title="View activity log" aria-haspopup="dialog"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M3 11a9 9 0 1 1 2.6 7M3 4v7h7M12 7v5l3 2"/></svg></button></div></div>
    <div className="incident-fact-columns">
      <dl className="report-facts"><div><dt>Coordinates</dt><dd className="report-coordinates"><span>{report.latitude.toFixed(6)}, {report.longitude.toFixed(6)}</span><span className="report-coordinate-links"><a href={reportMapUrl(report)} target="_blank" rel="noreferrer" aria-label="Open coordinates in Google Maps" title="Open in Google Maps"><img src="/icons/google-maps.ico" width="20" height="20" alt="" /></a><a href={reportMapyUrl(report)} target="_blank" rel="noreferrer" aria-label="Open coordinates in Mapy" title="Open in Mapy"><img src="/icons/mapy.png" width="20" height="20" alt="" /></a></span></dd></div><div><dt>Observed</dt><dd>{new Date(report.observedAtMs).toLocaleString()}</dd></div><div><dt>Reported by</dt><dd>{report.origin === 'organisation' ? 'Organisation' : 'Hiker'}</dd></div></dl>
      <dl className="report-facts"><div><dt>Location source</dt><dd>{report.locationSource}{report.accuracyM != null ? ` · ±${Math.round(report.accuracyM)} m` : ''}</dd></div><div><dt>Trail access</dt><dd>{report.passability}</dd></div>{report.contactEmail && <div><dt>Contact (private)</dt><dd>{report.contactEmail}</dd></div>}</dl>
      <dl className="report-facts">{report.stageId && <div><dt>Stage</dt><dd>{report.stageId}</dd></div>}<div><dt>Priority</dt><dd>{report.priority}</dd>{!!report.photos.length && <><dt className="incident-photos-label">Photos ({report.photos.length})</dt><dd className="report-photos">{report.photos.map(p => <button key={p.id} disabled={busy} onClick={() => void act(async () => setPhotoView(await reportPhoto(report.id, p.id, false)))} aria-label="Open full report photo">{photos[p.id] ? <img src={photos[p.id]} alt="Reported trail problem" /> : <span>Loading photo…</span>}</button>)}</dd></>}</div></dl>
    </div>
    {photoView && <dialog open className="report-photo-view"><button type="button" className="notify-dialog-close" aria-label="Close photo" onClick={() => setPhotoView(null)}>×</button><img src={photoView} alt="Full report photo" /></dialog>}
    {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
    <ReportActivityDialog open={activityOpen} onClose={() => setActivityOpen(false)} reference={report.ticketReference || report.id} events={events} loading={activityLoading} error={activityError}/>
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
