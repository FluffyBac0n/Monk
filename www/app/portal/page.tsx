'use client';

import { FormEvent, useEffect, useMemo, useState } from 'react';
import { AuthPanel } from '@/components/AuthPanel';
import { PortalHeader } from '@/components/PortalHeader';
import {
  deleteDraft,
  listStages,
  listTrails,
  saveSubmission,
  watchOwnerSubmissions,
} from '@/lib/accommodations';
import type { AccommodationSubmission, StageOption, TrailOption } from '@/lib/models';
import { statusLabels } from '@/lib/models';
import { useAuthState } from '@/lib/use-auth';

const lodgingTypes = ['Hotel', 'Guesthouse', 'Hostel', 'Apartment', 'Villa', 'Camping'];

const emptyForm = {
  trailId: 'cyprus-e4',
  trailName: 'E4 — Cyprus',
  stageId: '',
  stageName: '',
  stageSequence: 0,
  name: '',
  type: 'Hotel',
  village: '',
  address: '',
  description: '',
  phone: '',
  email: '',
  website: '',
  whatsapp: '',
  googleMapsUrl: '',
  priceMinEur: '',
  priceMaxEur: '',
  distanceFromTrailKm: '',
  capacityPeople: '',
  monthsOpen: '',
  latitude: '',
  longitude: '',
  policyAgreement: false,
};

function toForm(row: AccommodationSubmission) {
  return {
    trailId: row.trailId,
    trailName: row.trailName,
    stageId: row.stageId,
    stageName: row.stageName,
    stageSequence: row.stageSequence ?? 0,
    name: row.name,
    type: row.type,
    village: row.village,
    address: row.address,
    description: row.description,
    phone: row.phone,
    email: row.email,
    website: row.website,
    whatsapp: row.whatsapp ?? '',
    googleMapsUrl: row.googleMapsUrl ?? '',
    priceMinEur: row.priceMinEur?.toString() ?? '',
    priceMaxEur: row.priceMaxEur?.toString() ?? '',
    distanceFromTrailKm: row.distanceFromTrailKm?.toString() ?? '',
    capacityPeople: row.capacityPeople?.toString() ?? '',
    monthsOpen: row.monthsOpen ?? '',
    latitude: row.latitude?.toString() ?? '',
    longitude: row.longitude?.toString() ?? '',
    policyAgreement: row.policyAgreement,
  };
}

function errorMessage(caught: unknown, fallback: string) {
  return caught instanceof Error ? caught.message : fallback;
}

export default function OwnerPortal() {
  const { user, loading } = useAuthState();
  const [submissions, setSubmissions] = useState<AccommodationSubmission[]>([]);
  const [trails, setTrails] = useState<TrailOption[]>([{ id: 'cyprus-e4', name: 'E4 — Cyprus' }]);
  const [stages, setStages] = useState<StageOption[]>([]);
  const [editing, setEditing] = useState<AccommodationSubmission | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [showForm, setShowForm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [deletingId, setDeletingId] = useState('');
  const [trailsLoading, setTrailsLoading] = useState(true);
  const [stagesLoading, setStagesLoading] = useState(true);
  const [catalogError, setCatalogError] = useState('');
  const [catalogRetry, setCatalogRetry] = useState(0);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  useEffect(() => {
    if (!user) return;
    return watchOwnerSubmissions(user.uid, setSubmissions, (caught) => setError(caught.message));
  }, [user]);

  useEffect(() => {
    if (!user) return;
    let active = true;
    listTrails()
      .then((rows) => { if (active) setTrails(rows); })
      .catch((caught) => { if (active) setCatalogError(errorMessage(caught, 'Trail choices could not be loaded.')); })
      .finally(() => { if (active) setTrailsLoading(false); });
    return () => { active = false; };
  }, [user, catalogRetry]);

  useEffect(() => {
    if (!user || !form.trailId) return;
    let active = true;
    listStages(form.trailId)
      .then((rows) => {
        if (!active) return;
        setStages(rows);
        if (!rows.length) setCatalogError('No stages are available for this trail yet.');
      })
      .catch((caught) => { if (active) setCatalogError(errorMessage(caught, 'Trail stages could not be loaded.')); })
      .finally(() => { if (active) setStagesLoading(false); });
    return () => { active = false; };
  }, [user, form.trailId, catalogRetry]);

  const counts = useMemo(() => ({
    live: submissions.filter((row) => row.status === 'approved').length,
    review: submissions.filter((row) => ['pending', 'pending_update'].includes(row.status)).length,
    attention: submissions.filter((row) => row.status === 'changes_requested').length,
  }), [submissions]);

  function update<K extends keyof typeof form>(key: K, value: (typeof form)[K]) {
    setForm((current) => ({ ...current, [key]: value }));
  }

  function startNew() {
    setEditing(null);
    setCatalogError('');
    setStages([]);
    setStagesLoading(true);
    setCatalogRetry((value) => value + 1);
    setForm({ ...emptyForm, email: user?.email || '' });
    setShowForm(true);
    setNotice('');
    setError('');
  }

  function startEdit(row: AccommodationSubmission) {
    setEditing(row);
    setCatalogError('');
    setStages([]);
    setStagesLoading(true);
    setCatalogRetry((value) => value + 1);
    setForm(toForm(row));
    setShowForm(true);
    setNotice('');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!user) return;
    if (trailsLoading || stagesLoading || catalogError || !stages.length) {
      setError('Wait for the trail stages to load before submitting.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const selectedTrail = trails.find((row) => row.id === form.trailId);
      const selectedStage = stages.find((row) => row.id === form.stageId);
      await saveSubmission(user, {
        trailId: form.trailId,
        trailName: selectedTrail?.name || form.trailName,
        stageId: form.stageId,
        stageName: selectedStage?.name || form.stageName,
        stageSequence: selectedStage?.sequence ?? form.stageSequence,
        name: form.name.trim(),
        type: form.type,
        village: form.village.trim(),
        address: form.address.trim(),
        description: form.description.trim(),
        phone: form.phone.trim(),
        email: form.email.trim(),
        website: form.website.trim(),
        whatsapp: form.whatsapp.trim(),
        googleMapsUrl: form.googleMapsUrl.trim(),
        priceMinEur: form.priceMinEur === '' ? null : Number(form.priceMinEur),
        priceMaxEur: form.priceMaxEur === '' ? null : Number(form.priceMaxEur),
        distanceFromTrailKm: form.distanceFromTrailKm === '' ? null : Number(form.distanceFromTrailKm),
        capacityPeople: form.capacityPeople === '' ? null : Number(form.capacityPeople),
        monthsOpen: form.monthsOpen.trim(),
        latitude: form.latitude === '' ? null : Number(form.latitude),
        longitude: form.longitude === '' ? null : Number(form.longitude),
        policyAgreement: form.policyAgreement,
      }, editing || undefined);
      setShowForm(false);
      setEditing(null);
      setNotice(editing?.status === 'approved' ? 'Your update was submitted for review. The current live listing remains visible until approval.' : 'Accommodation submitted for review.');
    } catch (caught) {
      setError(errorMessage(caught, 'Submission failed.'));
    } finally {
      setBusy(false);
    }
  }

  async function removeListing(row: AccommodationSubmission) {
    if (!user || !window.confirm(`Delete ${row.name}? This cannot be undone.`)) return;
    setDeletingId(row.id);
    setError('');
    setNotice('');
    try {
      await deleteDraft(user, row);
      setNotice('Accommodation deleted.');
    } catch (caught) {
      setError(errorMessage(caught, 'The accommodation could not be deleted.'));
    } finally {
      setDeletingId('');
    }
  }

  function retryCatalog() {
    setCatalogError('');
    setTrailsLoading(true);
    setStagesLoading(true);
    setCatalogRetry((value) => value + 1);
  }

  function selectTrail(trailId: string) {
    setCatalogError('');
    setStages([]);
    setStagesLoading(true);
    setForm((current) => ({ ...current, trailId, stageId: '', stageName: '', stageSequence: 0 }));
  }

  if (loading) return <div className="loading-screen">Loading EuroTrex…</div>;
  if (!user) return <main className="portal-page"><PortalHeader /><AuthPanel onNotice={setNotice} onError={setError} /></main>;

  return (
    <main className="portal-page">
      <PortalHeader user={user} />
      <div className="dashboard-shell">
        <section className="dashboard-title">
          <div><p className="eyebrow dark">OWNER WORKSPACE</p><h1>Your trail stays.</h1><p>Submit accommodation for review and keep every approved listing accurate.</p></div>
          <button className="button button-primary" onClick={startNew}>+ Add accommodation</button>
        </section>

        <section className="metric-grid" aria-label="Listing summary">
          <article><span>{submissions.length}</span><p>Total listings</p></article>
          <article><span>{counts.live}</span><p>Live in the app</p></article>
          <article><span>{counts.review}</span><p>Under review</p></article>
          <article><span>{counts.attention}</span><p>Need attention</p></article>
        </section>

        {notice && <p className="notice success" role="status">{notice}</p>}
        {error && <p className="notice error" role="alert">{error}</p>}

        {showForm && (
          <section className="form-panel">
            <div className="panel-heading"><div><p className="eyebrow dark">{editing ? 'UPDATE LISTING' : 'NEW LISTING'}</p><h2>{editing ? editing.name : 'Accommodation details'}</h2></div><button className="text-button" onClick={() => setShowForm(false)}>Close</button></div>
            {editing?.status === 'approved' && <p className="notice info">Changes to a live listing are reviewed before replacing the version in the app.</p>}
            {catalogError && <p className="notice error with-action" role="alert"><span>{catalogError}</span><button type="button" className="text-button" onClick={retryCatalog}>Retry</button></p>}
            <form className="form-grid" onSubmit={submit}>
              <label>Trail<select value={form.trailId} disabled={trailsLoading} onChange={(event) => selectTrail(event.target.value)} required>{trails.map((trail) => <option key={trail.id} value={trail.id}>{trail.name}</option>)}</select></label>
              <label>Nearest trail stage<select value={form.stageId} disabled={stagesLoading || Boolean(catalogError)} onChange={(event) => update('stageId', event.target.value)} required><option value="">{stagesLoading ? 'Loading stages…' : 'Select a named location'}</option>{stages.map((stage) => <option key={stage.id} value={stage.id}>{stage.name}</option>)}</select></label>
              <label>Accommodation name<input value={form.name} onChange={(event) => update('name', event.target.value)} required /></label>
              <label>Type<select value={form.type} onChange={(event) => update('type', event.target.value)}>{lodgingTypes.map((type) => <option key={type}>{type}</option>)}</select></label>
              <label>Village or town<input value={form.village} onChange={(event) => update('village', event.target.value)} required /></label>
              <label>Street address<input value={form.address} onChange={(event) => update('address', event.target.value)} required /></label>
              <label>Minimum nightly price (€)<input type="number" min="0" step="1" value={form.priceMinEur} onChange={(event) => update('priceMinEur', event.target.value)} required /></label>
              <label>Maximum nightly price (€)<input type="number" min="0" step="1" value={form.priceMaxEur} onChange={(event) => update('priceMaxEur', event.target.value)} required /></label>
              <label>Booking website<input type="url" value={form.website} onChange={(event) => update('website', event.target.value)} placeholder="https://" required /></label>
              <label>Public email<input type="email" value={form.email} onChange={(event) => update('email', event.target.value)} required /></label>
              <label>Public phone<input type="tel" value={form.phone} onChange={(event) => update('phone', event.target.value)} required /></label>
              <label>WhatsApp number<input type="tel" value={form.whatsapp} onChange={(event) => update('whatsapp', event.target.value)} placeholder="Optional" /></label>
              <label>Google Maps link<input type="url" value={form.googleMapsUrl} onChange={(event) => update('googleMapsUrl', event.target.value)} placeholder="https://maps.google.com/…" /></label>
              <label>Distance from trail (km)<input type="number" min="0" step="0.1" value={form.distanceFromTrailKm} onChange={(event) => update('distanceFromTrailKm', event.target.value)} required /></label>
              <label>Maximum guests<input type="number" min="1" step="1" value={form.capacityPeople} onChange={(event) => update('capacityPeople', event.target.value)} /></label>
              <label>Months open<input value={form.monthsOpen} onChange={(event) => update('monthsOpen', event.target.value)} placeholder="e.g. March–November or year-round" /></label>
              <label>Latitude<input type="number" min="-90" max="90" step="any" value={form.latitude} onChange={(event) => update('latitude', event.target.value)} /></label>
              <label>Longitude<input type="number" min="-180" max="180" step="any" value={form.longitude} onChange={(event) => update('longitude', event.target.value)} /></label>
              <label className="full">Description<textarea rows={4} maxLength={800} value={form.description} onChange={(event) => update('description', event.target.value)} required /></label>
              <label className="check-label full"><input type="checkbox" checked={form.policyAgreement} onChange={(event) => update('policyAgreement', event.target.checked)} required /><span>I confirm that I represent this accommodation, the information is accurate, and I accept the <a href="/partner-terms" target="_blank">partner listing policy</a>.</span></label>
              <div className="form-actions full"><button type="button" className="button button-secondary" onClick={() => setShowForm(false)}>Cancel</button><button className="button button-primary" disabled={busy || trailsLoading || stagesLoading || Boolean(catalogError) || !stages.length}>{busy ? 'Submitting…' : editing ? 'Submit update' : 'Submit for review'}</button></div>
            </form>
          </section>
        )}

        <section className="list-section">
          <div className="panel-heading"><div><p className="eyebrow dark">MY ACCOMMODATIONS</p><h2>Listings and reviews</h2></div></div>
          {!submissions.length ? (
            <div className="empty-state"><span>⌂</span><h3>No accommodation submitted yet.</h3><p>Create your first listing and the EuroTrex team will review it before it appears in the app.</p><button className="button button-primary" onClick={startNew}>Add accommodation</button></div>
          ) : (
            <div className="listing-grid">
              {submissions.map((row) => (
                <article className="listing-card" key={row.id}>
                  <div className="card-top"><span className={`status status-${row.status}`}>{statusLabels[row.status]}</span><span>{row.trailName}</span></div>
                  <h3>{row.name}</h3>
                  <p>{row.type} · {row.village} · near {row.stageName}</p>
                  {row.reviewNote && <blockquote><strong>Reviewer note</strong>{row.reviewNote}</blockquote>}
                  <div className="card-actions">{row.status !== 'removed' && <button className="button button-secondary" onClick={() => startEdit(row)}>Edit details</button>}{['draft', 'rejected', 'changes_requested'].includes(row.status) && <button className="text-button danger" disabled={deletingId === row.id} onClick={() => void removeListing(row)}>{deletingId === row.id ? 'Deleting…' : 'Delete'}</button>}</div>
                </article>
              ))}
            </div>
          )}
        </section>
      </div>
    </main>
  );
}
