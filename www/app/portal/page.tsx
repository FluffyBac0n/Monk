'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import type { User } from 'firebase/auth';
import { AccommodationWizard, MobileAccommodationPreview, emptyAccommodationForm, submissionToDraft } from '@/components/AccommodationWizard';
import { AccountVerificationGate } from '@/components/AccountVerificationGate';
import { AuthPanel } from '@/components/AuthPanel';
import { PortalHeader } from '@/components/PortalHeader';
import {
  deleteAccommodationDraft,
  deleteDraft as deleteSubmission,
  getOwnerAccess,
  watchOwnerDrafts,
  watchPublishedLodgingsForSubmissions,
  watchOwnerSubmissions,
} from '@/lib/accommodations';
import type { AccommodationDraft, AccommodationDraftValues, AccommodationSubmission, PublishedLodging } from '@/lib/models';
import { statusLabels, submissionHasPublishedVersion } from '@/lib/models';
import { useAuthState } from '@/lib/use-auth';
import { trailDisplayName } from '@/lib/trail-names';

type EditorState = {
  draftId: string;
  values: AccommodationDraftValues;
  step: number;
  source: AccommodationSubmission | null;
};

function errorMessage(caught: unknown, fallback: string) {
  return caught instanceof Error ? caught.message : fallback;
}

function displayDate(value: unknown) {
  if (!value || typeof value !== 'object' || !('toDate' in value) || typeof value.toDate !== 'function') return null;
  const date = value.toDate();
  return date instanceof Date && Number.isFinite(date.getTime()) ? new Intl.DateTimeFormat('en-GB', { dateStyle: 'medium' }).format(date) : null;
}

export default function OwnerPortal() {
  const { user, loading } = useAuthState();

  if (loading) return <div className="loading-screen">Loading EuroTrex…</div>;
  if (!user) return <main className="portal-page"><PortalHeader /><AuthPanel /></main>;
  if (!user.emailVerified) return <AccountVerificationGate user={user} />;
  return <OwnerAccessResolver key={user.uid} user={user} />;
}

function OwnerAccessResolver({ user }: { user: User }) {
  const [access, setAccess] = useState<{ allowed: boolean; isAdmin: boolean; reason: string | null } | null>(null);

  useEffect(() => {
    let active = true;
    getOwnerAccess(user)
      .then((result) => { if (active) setAccess(result); })
      .catch(() => { if (active) setAccess({ allowed: false, isAdmin: false, reason: 'error' }); });
    return () => { active = false; };
  }, [user]);

  if (access === null) return <div className="loading-screen">Checking host access…</div>;
  if (!access.allowed) {
    const disabled = access.reason === 'disabled';
    const pending = access.reason === 'pending';
    return <main className="portal-page"><PortalHeader user={user} /><section className="access-card"><span>{pending ? 'Request received' : 'Host access'}</span><h1>{pending ? 'Your host account is under review.' : disabled ? 'Host access is paused.' : 'Host access needs attention.'}</h1><p>{pending ? 'Your email is verified and your company details have reached EuroTrex. Review normally takes 1–3 days. Return to the portal to check access.' : disabled ? 'This host profile is currently disabled. Contact EuroTrex if you believe this is a mistake.' : 'We could not confirm active host access for this account. Try again or contact EuroTrex for help.'}</p><div className="card-actions"><a className="button button-primary" href="/portal">Check access again</a><a className="button button-secondary" href="/get-involved?interest=host">Contact EuroTrex</a></div></section></main>;
  }

  return <OwnerWorkspace user={user} canAccessAdmin={access.isAdmin} />;
}

function OwnerWorkspace({ user, canAccessAdmin }: { user: User; canAccessAdmin: boolean }) {
  const [submissions, setSubmissions] = useState<AccommodationSubmission[]>([]);
  const [published, setPublished] = useState<PublishedLodging[]>([]);
  const [drafts, setDrafts] = useState<AccommodationDraft[]>([]);
  const [editor, setEditor] = useState<EditorState | null>(null);
  const [deletingId, setDeletingId] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const launchRef = useRef<HTMLElement | null>(null);
  const confirmationRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const stopSubmissions = watchOwnerSubmissions(user.uid, setSubmissions, (caught) => setError(caught.message));
    const stopDrafts = watchOwnerDrafts(user.uid, setDrafts, (caught) => setError(caught.message));
    return () => { stopSubmissions(); stopDrafts(); };
  }, [user]);

  useEffect(() => watchPublishedLodgingsForSubmissions(
    submissions,
    setPublished,
    (caught) => setError(caught.message),
  ), [submissions]);

  useEffect(() => { if (confirmation) confirmationRef.current?.focus(); }, [confirmation]);

  const counts = useMemo(() => ({
    live: published.length,
    review: submissions.filter((row) => ['pending', 'pending_update'].includes(row.status)).length,
    attention: submissions.filter((row) => row.status === 'changes_requested').length,
  }), [published.length, submissions]);

  function publishedVersionFor(row: AccommodationSubmission) {
    return published.find((live) => live.id === row.publishedLodgingId && live.trailId === row.publishedTrailId);
  }

  function rememberLauncher(target: EventTarget | null) {
    launchRef.current = target instanceof HTMLElement ? target : null;
  }

  function startNew(target: EventTarget | null) {
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
    if (!window.confirm(`Delete ${row.name}? This cannot be undone.`)) return;
    setDeletingId(row.id); setError(''); setNotice('');
    try { await deleteSubmission(user, row); setNotice('Accommodation deleted.'); }
    catch (caught) { setError(errorMessage(caught, 'The accommodation could not be deleted.')); }
    finally { setDeletingId(''); }
  }

  async function removeDraft(draft: AccommodationDraft) {
    if (!window.confirm(`Delete the draft for ${draft.values.name || 'this accommodation'}?`)) return;
    setDeletingId(draft.id); setError('');
    try { await deleteAccommodationDraft(user, draft.id); setNotice('Draft deleted.'); }
    catch (caught) { setError(errorMessage(caught, 'The draft could not be deleted.')); }
    finally { setDeletingId(''); }
  }

  return (
    <main className="portal-page">
      <PortalHeader user={user} canAccessAdmin={canAccessAdmin} />
      <div className="dashboard-shell">
        <section className="dashboard-title">
          <div><p className="eyebrow">OWNER WORKSPACE</p><h1>Your accommodation listings.</h1><p>Create a guided draft, submit it for review and keep every live listing accurate.</p></div>
          <button className="button button-primary" onClick={(event) => startNew(event.currentTarget)}>+ Add accommodation</button>
        </section>

        <section className="metric-grid owner-summary" aria-label="Listing summary">
          <article><span>{drafts.length}</span><p>Saved drafts</p></article><article><span>{counts.live}</span><p>Live listings</p></article><article><span>{counts.review}</span><p>Awaiting review</p></article><article><span>{counts.attention}</span><p>Needs attention</p></article>
        </section>

        {!editor && <section className="next-action" aria-labelledby="next-action-title"><div><p className="eyebrow">YOUR NEXT STEP</p><h2 id="next-action-title">{counts.attention ? 'A listing needs your attention.' : drafts.length ? 'Pick up your saved draft.' : counts.review ? 'Your listing is with our reviewers.' : counts.live ? 'Keep your published details current.' : 'Prepare your first listing.'}</h2><p>{counts.attention ? 'Read the reviewer’s note below, update the details and resubmit.' : drafts.length ? 'Check the app preview before sending it for review.' : counts.review ? 'Review normally takes 1–3 days. Check below for status changes.' : 'Preview how your accommodation appears to hikers before submitting.'}</p></div>{drafts.length > 0 && !counts.attention && <button className="button button-primary" onClick={(event) => resumeDraft(drafts[0], event.currentTarget)}>Continue draft</button>}<a className="simple-link" href="/help#hosts">Host help</a></section>}

        {notice && <p className="notice success" role="status">{notice}</p>}
        {error && <p className="notice error" role="alert">{error}</p>}
        {confirmation && <div className="submission-confirmation" role="status" tabIndex={-1} ref={confirmationRef}><span aria-hidden="true">✓</span><div><p className="eyebrow">SUBMISSION RECEIVED</p><h2>It’s with the EuroTrex team.</h2><p>{confirmation}</p><p>Review normally takes 1–3 days. Return here to check the status.</p><button className="button button-primary" onClick={() => setConfirmation('')}>Return to listings</button></div></div>}

        {editor && <AccommodationWizard key={`${editor.draftId}-${editor.source?.id || 'new'}`} user={user} initialValues={editor.values} initialStep={editor.step} initialDraftId={editor.draftId} sourceSubmission={editor.source} onClose={closeEditor} onSubmitted={submitted} />}

        {drafts.length > 0 && (
          <section className="list-section draft-section"><div className="panel-heading"><div><p className="eyebrow">SAVED DRAFTS</p><h2>Continue where you stopped</h2></div><p>Drafts autosave as you work.</p></div><div className="listing-grid">{drafts.map((draft) => <article className="listing-card" key={draft.id}><div className="card-top"><span className="status">Draft · step {draft.currentStep} of 4</span><span>{trailDisplayName(draft.values.trailId, draft.values.trailName)}</span></div><h3>{draft.values.name || 'Untitled accommodation'}</h3><p>{draft.values.type}{draft.values.village ? ` · ${draft.values.village}` : ''}</p><div className="card-actions"><button className="button button-secondary" onClick={(event) => resumeDraft(draft, event.currentTarget)}>Continue draft</button><button className="text-button danger" disabled={deletingId === draft.id} onClick={() => void removeDraft(draft)}>{deletingId === draft.id ? 'Deleting…' : 'Delete'}</button></div></article>)}</div></section>
        )}

        <section className="list-section">
          <div className="panel-heading"><div><p className="eyebrow">MY LISTINGS</p><h2>Listings and reviews</h2></div></div>
          {!submissions.length ? <div className="empty-state"><span>⌂</span><h3>No listings submitted yet.</h3><p>Create a draft at your pace. The EuroTrex team reviews it only after you submit.</p><button className="button button-primary" onClick={(event) => startNew(event.currentTarget)}>Add accommodation</button></div> : <div className="listing-grid">{submissions.map((row) => {
            const live = publishedVersionFor(row);
            const hasLiveVersion = Boolean(live) || submissionHasPublishedVersion(row);
            const showVersionComparison = Boolean(live && row.status !== 'approved' && row.status !== 'removed');
            return <article className={`listing-card ${showVersionComparison ? 'listing-card-versions' : ''}`} key={row.id}>
              <div className="card-top"><div className="status-row">{hasLiveVersion && <span className="status status-approved">Published</span>}{(!hasLiveVersion || row.status !== 'approved') && <span className={`status status-${row.status}`}>{statusLabels[row.status]}</span>}</div><span>{trailDisplayName(row.trailId, row.trailName)}</span></div>
              {showVersionComparison && live ? <div className="listing-version-grid">
                <section><span>LIVE IN THE APP</span><h3>{live.name || row.name}</h3><p>{live.type || row.type} · {live.village || row.village}<br />Nearest stage point: {live.stageName || row.stageName}</p></section>
                <section><span>PROPOSED UPDATE</span><h3>{row.name}</h3><p>{row.type} · {row.village}<br />Nearest stage point: {row.stageName}</p></section>
              </div> : <><h3>{row.name}</h3><p>{row.type} · {row.village} · nearest stage point: {row.stageName}</p></>}
              {row.reviewNote && <blockquote><strong>Reviewer note</strong>{row.reviewNote}</blockquote>}
              <p className="listing-dates">{displayDate(row.createdAt) && <>Created {displayDate(row.createdAt)} · </>}{displayDate(row.updatedAt) && <>Updated {displayDate(row.updatedAt)}<br /></>}{['pending', 'pending_update'].includes(row.status) ? 'Next: EuroTrex reviews your submission, normally within 1–3 days.' : row.status === 'changes_requested' ? 'Next: update the requested details and submit again.' : row.status === 'approved' ? 'Published. Submit any changes for review when details change.' : 'Open the details for your next step.'}</p>
              <details className="listing-preview"><summary>Preview as hikers see it</summary><MobileAccommodationPreview form={submissionToDraft(row)} stageName={row.stageName} />{row.status !== 'approved' && <p className="data-caveat">This previews your submitted details, not the current published version.</p>}</details>
              <div className="card-actions">{row.status !== 'removed' && <button className="button button-secondary" onClick={(event) => startEdit(row, event.currentTarget)}>Edit details</button>}{['draft', 'rejected', 'changes_requested'].includes(row.status) && <button className="text-button danger" disabled={deletingId === row.id} onClick={() => void removeListing(row)}>{deletingId === row.id ? 'Deleting…' : 'Delete'}</button>}</div>
            </article>;
          })}</div>}
        </section>
      </div>
    </main>
  );
}
