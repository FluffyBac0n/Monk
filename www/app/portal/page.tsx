'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { AccommodationWizard, emptyAccommodationForm, submissionToDraft } from '@/components/AccommodationWizard';
import { AuthPanel } from '@/components/AuthPanel';
import { PortalHeader } from '@/components/PortalHeader';
import {
  deleteAccommodationDraft,
  deleteDraft as deleteSubmission,
  userIsAdmin,
  watchOwnerDrafts,
  watchOwnerPublishedLodgings,
  watchOwnerSubmissions,
} from '@/lib/accommodations';
import type { AccommodationDraft, AccommodationDraftValues, AccommodationSubmission, PublishedLodging } from '@/lib/models';
import { statusLabels, submissionHasPublishedVersion } from '@/lib/models';
import { useAuthState } from '@/lib/use-auth';

type EditorState = {
  draftId: string;
  values: AccommodationDraftValues;
  step: number;
  source: AccommodationSubmission | null;
};

function errorMessage(caught: unknown, fallback: string) {
  return caught instanceof Error ? caught.message : fallback;
}

export default function OwnerPortal() {
  const { user, loading } = useAuthState();
  const [submissions, setSubmissions] = useState<AccommodationSubmission[]>([]);
  const [published, setPublished] = useState<PublishedLodging[]>([]);
  const [drafts, setDrafts] = useState<AccommodationDraft[]>([]);
  const [editor, setEditor] = useState<EditorState | null>(null);
  const [canAccessAdmin, setCanAccessAdmin] = useState(false);
  const [deletingId, setDeletingId] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const launchRef = useRef<HTMLElement | null>(null);
  const confirmationRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!user) return;
    const stopSubmissions = watchOwnerSubmissions(user.uid, setSubmissions, (caught) => setError(caught.message));
    const stopDrafts = watchOwnerDrafts(user.uid, setDrafts, (caught) => setError(caught.message));
    const stopPublished = watchOwnerPublishedLodgings(user.uid, setPublished, (caught) => setError(caught.message));
    userIsAdmin(user).then(setCanAccessAdmin).catch(() => setCanAccessAdmin(false));
    return () => { stopSubmissions(); stopDrafts(); stopPublished(); };
  }, [user]);

  useEffect(() => { if (confirmation) confirmationRef.current?.focus(); }, [confirmation]);

  const counts = useMemo(() => ({
    live: published.length,
    review: submissions.filter((row) => ['pending', 'pending_update'].includes(row.status)).length,
    attention: submissions.filter((row) => row.status === 'changes_requested').length,
  }), [published.length, submissions]);

  function publishedVersionFor(row: AccommodationSubmission) {
    return published.find((live) => live.sourceSubmissionId === row.id
      || (live.id === row.publishedLodgingId && live.trailId === row.publishedTrailId));
  }

  function rememberLauncher(target: EventTarget | null) {
    launchRef.current = target instanceof HTMLElement ? target : null;
  }

  function startNew(target: EventTarget | null) {
    if (!user) return;
    rememberLauncher(target);
    setEditor({ draftId: '', values: { ...emptyAccommodationForm, email: user.email || '' }, step: 1, source: null });
    setNotice(''); setConfirmation(''); setError('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function startEdit(row: AccommodationSubmission, target: EventTarget | null) {
    rememberLauncher(target);
    const existingDraft = drafts.find((draft) => draft.sourceSubmissionId === row.id);
    setEditor(existingDraft
      ? { draftId: existingDraft.id, values: existingDraft.values, step: existingDraft.currentStep, source: row }
      : { draftId: '', values: submissionToDraft(row), step: 1, source: row });
    setNotice(''); setConfirmation(''); setError('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function resumeDraft(draft: AccommodationDraft, target: EventTarget | null) {
    rememberLauncher(target);
    const source = submissions.find((row) => row.id === draft.sourceSubmissionId) || null;
    setEditor({ draftId: draft.id, values: draft.values, step: draft.currentStep, source });
    setNotice(''); setConfirmation(''); setError('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  function closeEditor() {
    setEditor(null);
    window.requestAnimationFrame(() => launchRef.current?.focus());
  }

  function submitted(message: string) {
    setEditor(null);
    setConfirmation(message);
  }

  async function removeListing(row: AccommodationSubmission) {
    if (!user || !window.confirm(`Delete ${row.name}? This cannot be undone.`)) return;
    setDeletingId(row.id); setError(''); setNotice('');
    try { await deleteSubmission(user, row); setNotice('Accommodation deleted.'); }
    catch (caught) { setError(errorMessage(caught, 'The accommodation could not be deleted.')); }
    finally { setDeletingId(''); }
  }

  async function removeDraft(draft: AccommodationDraft) {
    if (!user || !window.confirm(`Delete the draft for ${draft.values.name || 'this accommodation'}?`)) return;
    setDeletingId(draft.id); setError('');
    try { await deleteAccommodationDraft(user, draft.id); setNotice('Draft deleted.'); }
    catch (caught) { setError(errorMessage(caught, 'The draft could not be deleted.')); }
    finally { setDeletingId(''); }
  }

  if (loading) return <div className="loading-screen">Loading EuroTrex…</div>;
  if (!user) return <main className="portal-page"><PortalHeader /><AuthPanel onNotice={setNotice} onError={setError} /></main>;

  return (
    <main className="portal-page">
      <PortalHeader user={user} canAccessAdmin={canAccessAdmin} />
      <div className="dashboard-shell">
        <section className="dashboard-title">
          <div><p className="eyebrow dark">OWNER WORKSPACE</p><h1>Your accommodation listings.</h1><p>Create a guided draft, submit it for review and keep every live listing accurate.</p></div>
          <button className="button button-primary" onClick={(event) => startNew(event.currentTarget)}>+ Add accommodation</button>
        </section>

        <section className="metric-grid" aria-label="Listing summary">
          <article><span>{drafts.length}</span><p>Saved drafts</p></article><article><span>{counts.live}</span><p>Live listings</p></article><article><span>{counts.review}</span><p>Awaiting review</p></article><article><span>{counts.attention}</span><p>Needs attention</p></article>
        </section>

        {notice && <p className="notice success" role="status">{notice}</p>}
        {error && <p className="notice error" role="alert">{error}</p>}
        {confirmation && <div className="submission-confirmation" role="status" tabIndex={-1} ref={confirmationRef}><span aria-hidden="true">✓</span><div><p className="eyebrow dark">SUBMISSION RECEIVED</p><h2>It’s with the EuroTrex team.</h2><p>{confirmation}</p><p>Review is manual during private testing. There is no guaranteed service window; you can return here at any time to see the current status.</p><button className="button button-primary" onClick={() => setConfirmation('')}>Return to listings</button></div></div>}

        {editor && <AccommodationWizard key={`${editor.draftId}-${editor.source?.id || 'new'}`} user={user} initialValues={editor.values} initialStep={editor.step} initialDraftId={editor.draftId} sourceSubmission={editor.source} onClose={closeEditor} onSubmitted={submitted} />}

        {drafts.length > 0 && (
          <section className="list-section draft-section"><div className="panel-heading"><div><p className="eyebrow dark">SAVED DRAFTS</p><h2>Continue where you stopped</h2></div><p>Drafts autosave as you work.</p></div><div className="listing-grid">{drafts.map((draft) => <article className="listing-card draft-card" key={draft.id}><div className="card-top"><span className="status">Draft · step {draft.currentStep} of 4</span><span>{draft.values.trailName}</span></div><h3>{draft.values.name || 'Untitled accommodation'}</h3><p>{draft.values.type}{draft.values.village ? ` · ${draft.values.village}` : ''}</p><div className="card-actions"><button className="button button-secondary" onClick={(event) => resumeDraft(draft, event.currentTarget)}>Continue draft</button><button className="text-button danger" disabled={deletingId === draft.id} onClick={() => void removeDraft(draft)}>{deletingId === draft.id ? 'Deleting…' : 'Delete'}</button></div></article>)}</div></section>
        )}

        <section className="list-section">
          <div className="panel-heading"><div><p className="eyebrow dark">MY LISTINGS</p><h2>Listings and reviews</h2></div></div>
          {!submissions.length ? <div className="empty-state"><span>⌂</span><h3>No listings submitted yet.</h3><p>Create a draft at your pace. The EuroTrex team reviews it only after you submit.</p><button className="button button-primary" onClick={(event) => startNew(event.currentTarget)}>Add accommodation</button></div> : <div className="listing-grid">{submissions.map((row) => {
            const live = publishedVersionFor(row);
            const hasLiveVersion = Boolean(live) || submissionHasPublishedVersion(row);
            const showVersionComparison = Boolean(live && row.status !== 'approved' && row.status !== 'removed');
            return <article className={`listing-card ${showVersionComparison ? 'listing-card-versions' : ''}`} key={row.id}>
              <div className="card-top"><div className="status-row">{hasLiveVersion && <span className="status status-approved">Live version</span>}{(!hasLiveVersion || row.status !== 'approved') && <span className={`status status-${row.status}`}>{statusLabels[row.status]}</span>}</div><span>{row.trailName}</span></div>
              {showVersionComparison && live ? <div className="listing-version-grid">
                <section><span>LIVE IN THE APP</span><h3>{live.name || row.name}</h3><p>{live.type || row.type} · {live.village || row.village}<br />Nearest stage point: {live.stageName || row.stageName}</p></section>
                <section><span>PROPOSED UPDATE</span><h3>{row.name}</h3><p>{row.type} · {row.village}<br />Nearest stage point: {row.stageName}</p></section>
              </div> : <><h3>{row.name}</h3><p>{row.type} · {row.village} · nearest stage point: {row.stageName}</p></>}
              {row.reviewNote && <blockquote><strong>Reviewer note</strong>{row.reviewNote}</blockquote>}
              <div className="card-actions">{row.status !== 'removed' && <button className="button button-secondary" onClick={(event) => startEdit(row, event.currentTarget)}>Edit details</button>}{['draft', 'rejected', 'changes_requested'].includes(row.status) && <button className="text-button danger" disabled={deletingId === row.id} onClick={() => void removeListing(row)}>{deletingId === row.id ? 'Deleting…' : 'Delete'}</button>}</div>
            </article>;
          })}</div>}
        </section>
      </div>
    </main>
  );
}
