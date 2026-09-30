'use client';

import { useEffect, useMemo, useState } from 'react';
import type { User } from 'firebase/auth';
import { AccountVerificationGate } from '@/components/AccountVerificationGate';
import { AuthPanel } from '@/components/AuthPanel';
import { PortalHeader } from '@/components/PortalHeader';
import {
  approveSubmission,
  normalizeHttpUrl,
  removePublishedLodging,
  removeSubmissionAccommodation,
  reviewSubmission,
  userIsAdmin,
  watchAllPublishedLodgings,
  watchAllSubmissions,
  watchAudit,
} from '@/lib/accommodations';
import type { AccommodationSubmission, AuditEntry, PublishedLodging, SubmissionStatus } from '@/lib/models';
import { statusLabels } from '@/lib/models';
import { useAuthState } from '@/lib/use-auth';
import { trailDisplayName } from '@/lib/trail-names';

type Tab = 'review' | 'all' | 'published' | 'audit';

function safeExternalUrl(value: string) {
  try { return normalizeHttpUrl(value, true); }
  catch { return ''; }
}

export default function AdminDashboard() {
  const { user, loading } = useAuthState();

  if (loading) return <div className="loading-screen">Loading EuroTrex…</div>;
  if (!user) return <main className="portal-page"><PortalHeader admin /><AuthPanel admin /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} admin />;
  return <AdminAccessResolver key={user.uid} user={user} />;
}

function AdminAccessResolver({ user }: { user: User }) {
  const [authorized, setAuthorized] = useState<boolean | null>(null);

  useEffect(() => {
    let active = true;
    userIsAdmin(user)
      .then((result) => { if (active) setAuthorized(result); })
      .catch(() => { if (active) setAuthorized(false); });
    return () => { active = false; };
  }, [user]);

  if (authorized === null) return <div className="loading-screen">Checking admin access…</div>;
  if (!authorized) return <main className="portal-page"><PortalHeader user={user} admin /><section className="access-card"><span>Restricted workspace</span><h1>Admin access required.</h1><p>Your account is signed in and verified but is not listed as a EuroTrex administrator.</p><a className="button button-primary" href="/portal">Go to owner portal</a></section></main>;

  return <AdminSession user={user} />;
}

function AdminSession({ user }: { user: User }) {
  const [submissions, setSubmissions] = useState<AccommodationSubmission[]>([]);
  const [published, setPublished] = useState<PublishedLodging[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [tab, setTab] = useState<Tab>('review');
  const [status, setStatus] = useState<'all' | SubmissionStatus>('all');
  const [search, setSearch] = useState('');
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const stopSubmissions = watchAllSubmissions(setSubmissions, (caught) => setError(caught.message));
    const stopPublished = watchAllPublishedLodgings(setPublished, (caught) => setError(caught.message));
    const stopAudit = watchAudit(setAudit, (caught) => setError(caught.message));
    return () => { stopSubmissions(); stopPublished(); stopAudit(); };
  }, [user]);

  const queue = submissions.filter((row) => ['pending', 'pending_update'].includes(row.status));
  const owners = new Set(submissions.map((row) => row.ownerId)).size;
  const filtered = useMemo(() => submissions.filter((row) => {
    const statusMatch = status === 'all' || row.status === status;
    const needle = search.trim().toLowerCase();
    const textMatch = !needle || [row.name, row.ownerEmail, row.village, row.stageName, row.trailName].join(' ').toLowerCase().includes(needle);
    return statusMatch && textMatch;
  }), [submissions, search, status]);
  const managedSubmissionByPath = useMemo(() => new Map(submissions
    .filter((row) => row.publishedLodgingId && row.publishedTrailId)
    .map((row) => [`${row.publishedTrailId}/${row.publishedLodgingId}`, row])), [submissions]);

  function publishedVersionFor(row: AccommodationSubmission) {
    return published.find((live) => live.id === row.publishedLodgingId && live.trailId === row.publishedTrailId);
  }

  async function act(id: string, action: () => Promise<void>) {
    setBusyId(id);
    setError('');
    try { await action(); } catch (caught) { setError(caught instanceof Error ? caught.message : 'Action failed.'); }
    finally { setBusyId(''); }
  }

  return (
    <main className="portal-page">
      <PortalHeader user={user} admin />
      <div className="dashboard-shell wide">
        <section className="dashboard-title">
          <div><p className="eyebrow">EUROTREX OPERATIONS</p><h1>Accommodation review.</h1><p>Verify ownership, protect trail quality and control every listing visible in the app.</p></div>
          <span className="admin-badge">Admin</span>
        </section>
        <section className="metric-grid">
          <article><span>{queue.length}</span><p>Awaiting review</p></article>
          <article><span>{published.length}</span><p>Live listings</p></article>
          <article><span>{owners}</span><p>Hosts</p></article>
          <article><span>{submissions.filter((row) => row.status === 'changes_requested').length}</span><p>Changes requested</p></article>
        </section>
        {error && <p className="notice error" role="alert">{error}</p>}

        <div className="dashboard-tabs" role="group" aria-label="Admin views">
          <button aria-pressed={tab === 'review'} className={tab === 'review' ? 'active' : ''} onClick={() => setTab('review')}>Review queue <b>{queue.length}</b></button>
          <button aria-pressed={tab === 'all'} className={tab === 'all' ? 'active' : ''} onClick={() => setTab('all')}>All submissions</button>
          <button aria-pressed={tab === 'published'} className={tab === 'published' ? 'active' : ''} onClick={() => setTab('published')}>Live listings</button>
          <button aria-pressed={tab === 'audit'} className={tab === 'audit' ? 'active' : ''} onClick={() => setTab('audit')}>Audit log</button>
        </div>

        {tab === 'review' && (
          <section className="admin-list">
            {!queue.length ? <div className="empty-state"><span>✓</span><h3>The review queue is clear.</h3><p>New owner submissions and updates will appear here.</p></div> : queue.map((row) => (
              <ReviewCard key={row.id} row={row} live={publishedVersionFor(row)} busy={busyId === row.id} onAct={(action) => act(row.id, action)} user={user} />
            ))}
          </section>
        )}

        {tab === 'all' && (
          <section>
            <div className="filters"><label>Search<input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Accommodation, owner, trail…" /></label><label>Status<select value={status} onChange={(event) => setStatus(event.target.value as typeof status)}><option value="all">All statuses</option>{Object.entries(statusLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label></div>
            <div className="table-wrap"><table><thead><tr><th>Accommodation</th><th>Trail & stage point</th><th>Owner</th><th>Status</th><th>Control</th></tr></thead><tbody>{filtered.map((row) => { const live = publishedVersionFor(row); return <tr key={row.id}><td><strong>{row.name}</strong><small>{row.type} · {row.village}</small></td><td>{trailDisplayName(row.trailId, row.trailName)}<small>{row.stageName}</small></td><td>{row.ownerEmail}</td><td><div className="status-row">{live && <span className="status status-approved">Published</span>}{(!live || row.status !== 'approved') && <span className={`status status-${row.status}`}>{statusLabels[row.status]}</span>}</div></td><td>{row.status === 'approved' ? <button className="text-button danger" disabled={busyId === row.id} onClick={() => { const note = window.prompt('Reason for removal (shown in the audit log)'); if (note) act(row.id, () => removeSubmissionAccommodation(user, row, note)); }}>Remove</button> : <button className="text-button" onClick={() => { setTab('review'); }}>Review</button>}</td></tr>; })}</tbody></table></div>
          </section>
        )}

        {tab === 'published' && (
          <section>
            <div className="panel-heading"><div><p className="eyebrow">APP INVENTORY</p><h2>Live listings by trail</h2></div><p>{published.length} entries</p></div>
            <div className="table-wrap"><table><thead><tr><th>Accommodation</th><th>Trail & stage point</th><th>Owner/source</th><th>Control</th></tr></thead><tbody>{published.map((row) => { const source = managedSubmissionByPath.get(`${row.trailId}/${row.id}`); return <tr key={`${row.trailId}-${row.id}`}><td><strong>{row.name || 'Unnamed accommodation'}</strong><small>{row.type || 'Type not set'} · {row.village || 'Location not set'}</small></td><td><strong>{row.trailId}</strong><small>{row.stageName || row.stageId || 'Not linked'}</small></td><td>{source ? 'Owner-managed' : 'Imported data'}<small>{source?.id || row.id}</small></td><td><button className="text-button danger" disabled={busyId === row.id} onClick={() => { const note = window.prompt('Reason for removing this accommodation'); if (note) act(row.id, () => removePublishedLodging(user, row, note, source)); }}>Remove from app</button></td></tr>; })}</tbody></table></div>
          </section>
        )}

        {tab === 'audit' && (
          <section>
            <div className="panel-heading"><div><p className="eyebrow">ACCOUNTABILITY</p><h2>Accommodation audit log</h2></div><p>{audit.length} events</p></div>
            <div className="table-wrap"><table><thead><tr><th>Action</th><th>Accommodation</th><th>Administrator</th><th>Note</th><th>Time</th></tr></thead><tbody>{audit.map((row) => <tr key={row.id}><td><span className="status">{row.action || 'updated'}</span></td><td><strong>{row.accommodationName || row.lodgingId || 'Accommodation'}</strong><small>{row.trailId}</small></td><td>{row.actorEmail || 'Admin'}</td><td>{row.note || '—'}</td><td>{row.createdAt?.toDate?.().toLocaleString() || 'Pending'}</td></tr>)}</tbody></table></div>
          </section>
        )}

        <section className="admin-guidance">
          <h2>Review safeguards</h2>
          <div><article><strong>Verify ownership</strong><p>Confirm the contact domain, business identity and right to manage the property.</p></article><article><strong>Check trail relevance</strong><p>Validate stage-point linkage, coordinates, realistic walking distance and seasonal access.</p></article><article><strong>Protect hikers</strong><p>Review pricing clarity, contact details, booking URL and any safety or policy reports.</p></article><article><strong>Keep an audit trail</strong><p>Every approval, rejection, change request and removal records the acting administrator.</p></article></div>
        </section>
      </div>
    </main>
  );
}

function ReviewCard({ row, live, busy, onAct, user }: { row: AccommodationSubmission; live?: PublishedLodging; busy: boolean; onAct: (action: () => Promise<void>) => void; user: User }) {
  const note = (title: string) => window.prompt(title) || '';
  const website = safeExternalUrl(row.website);
  return (
    <article className="review-card">
      <div className="review-main"><div className="card-top"><div className="status-row">{live && <span className="status status-approved">Published</span>}<span className={`status status-${row.status}`}>{statusLabels[row.status]}</span></div><span>{trailDisplayName(row.trailId, row.trailName)} · {row.stageName}</span></div>{live && row.status === 'pending_update' && <div className="listing-version-grid admin-version-grid"><section><span>LIVE IN THE APP</span><h3>{live.name || row.name}</h3><p>{live.type || row.type} · {live.village || row.village}<br />Nearest stage point: {live.stageName || row.stageName}</p></section><section><span>PROPOSED UPDATE</span><h3>{row.name}</h3><p>{row.type} · {row.village}<br />Nearest stage point: {row.stageName}</p></section></div>}<h2>{row.name}</h2><p>{row.type} · {row.village}</p><dl><div><dt>Owner</dt><dd>{row.ownerEmail}</dd></div><div><dt>Nightly price</dt><dd>€{row.priceMinEur ?? '—'}–€{row.priceMaxEur ?? '—'}</dd></div><div><dt>Trail distance</dt><dd>{row.distanceFromTrailKm ?? '—'} km</dd></div><div><dt>Contact</dt><dd>{row.phone}<br />{row.email}</dd></div><div><dt>Website</dt><dd>{website ? <a href={website} target="_blank" rel="noreferrer">Open booking site ↗</a> : 'Invalid URL'}</dd></div><div><dt>Coordinates</dt><dd>{row.latitude ?? '—'}, {row.longitude ?? '—'}</dd></div></dl><p className="review-description">{row.description}</p></div>
      <aside className="review-actions"><button className="button button-primary" disabled={busy} onClick={() => onAct(() => approveSubmission(user, row, 'Verified and approved'))}>Approve & publish</button><button className="button button-secondary" disabled={busy} onClick={() => { const value = note('What should the owner change?'); if (value) onAct(() => reviewSubmission(user, row, 'changes_requested', value)); }}>Request changes</button><button className="text-button danger" disabled={busy} onClick={() => { const value = note('Reason for rejection'); if (value) onAct(() => reviewSubmission(user, row, 'rejected', value)); }}>Reject</button></aside>
    </article>
  );
}
