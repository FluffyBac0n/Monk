'use client';

import type { User } from 'firebase/auth';
import { FormEvent, useEffect, useRef, useState } from 'react';
import {
  deleteAccommodationDraft,
  listStages,
  listTrails,
  saveAccommodationDraft,
  saveSubmission,
} from '@/lib/accommodations';
import type { AccommodationDraftValues, AccommodationSubmission, StageOption, TrailOption } from '@/lib/models';

const lodgingTypes = ['Hotel', 'Guesthouse', 'Hostel', 'Apartment', 'Villa', 'Camping'];
const stepLabels = ['Property details', 'Trail location', 'Contact and pricing', 'Review and submit'];

export const emptyAccommodationForm: AccommodationDraftValues = {
  trailId: 'cyprus-e4', trailName: 'E4 — Cyprus', stageId: '', stageName: '', stageSequence: 0,
  name: '', type: 'Hotel', village: '', address: '', description: '', phone: '', email: '', website: '', whatsapp: '', googleMapsUrl: '',
  priceMinEur: '', priceMaxEur: '', distanceFromTrailKm: '', capacityPeople: '', monthsOpen: '', latitude: '', longitude: '', policyAgreement: false,
};

export function submissionToDraft(row: AccommodationSubmission): AccommodationDraftValues {
  return {
    trailId: row.trailId, trailName: row.trailName, stageId: row.stageId, stageName: row.stageName, stageSequence: row.stageSequence ?? 0,
    name: row.name, type: row.type, village: row.village, address: row.address, description: row.description, phone: row.phone, email: row.email,
    website: row.website, whatsapp: row.whatsapp ?? '', googleMapsUrl: row.googleMapsUrl ?? '', priceMinEur: row.priceMinEur?.toString() ?? '',
    priceMaxEur: row.priceMaxEur?.toString() ?? '', distanceFromTrailKm: row.distanceFromTrailKm?.toString() ?? '', capacityPeople: row.capacityPeople?.toString() ?? '',
    monthsOpen: row.monthsOpen ?? '', latitude: row.latitude?.toString() ?? '', longitude: row.longitude?.toString() ?? '', policyAgreement: row.policyAgreement,
  };
}

function errorMessage(caught: unknown, fallback: string) {
  return caught instanceof Error ? caught.message : fallback;
}

export function AccommodationWizard({
  user, initialValues, initialStep = 1, initialDraftId = '', sourceSubmission, onClose, onSubmitted,
}: {
  user: User;
  initialValues: AccommodationDraftValues;
  initialStep?: number;
  initialDraftId?: string;
  sourceSubmission?: AccommodationSubmission | null;
  onClose: () => void;
  onSubmitted: (message: string) => void;
}) {
  const [form, setForm] = useState(initialValues);
  const [step, setStep] = useState(Math.min(4, Math.max(1, initialStep)));
  const [draftId, setDraftId] = useState(initialDraftId);
  const [trails, setTrails] = useState<TrailOption[]>([{ id: 'cyprus-e4', name: 'E4 — Cyprus' }]);
  const [stages, setStages] = useState<StageOption[]>([]);
  const [catalogBusy, setCatalogBusy] = useState(true);
  const [catalogError, setCatalogError] = useState('');
  const [dirty, setDirty] = useState(false);
  const [saveState, setSaveState] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const headingRef = useRef<HTMLHeadingElement>(null);

  useEffect(() => { headingRef.current?.focus(); }, [step]);

  useEffect(() => {
    let active = true;
    listTrails().then((rows) => { if (active) setTrails(rows); }).catch((caught) => { if (active) setCatalogError(errorMessage(caught, 'Trail choices could not be loaded.')); });
    return () => { active = false; };
  }, []);

  useEffect(() => {
    let active = true;
    listStages(form.trailId).then((rows) => {
      if (!active) return;
      setStages(rows);
      if (!rows.length) setCatalogError('No stage points are available for this trail yet.');
    }).catch((caught) => { if (active) setCatalogError(errorMessage(caught, 'Trail stages could not be loaded.')); }).finally(() => { if (active) setCatalogBusy(false); });
    return () => { active = false; };
  }, [form.trailId]);

  useEffect(() => {
    if (!dirty) return;
    const timer = window.setTimeout(() => { void persistDraft(); }, 1100);
    return () => window.clearTimeout(timer);
    // persistDraft intentionally uses the latest render values.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [form, step, dirty]);

  function update<K extends keyof AccommodationDraftValues>(key: K, value: AccommodationDraftValues[K]) {
    setForm((current) => ({ ...current, [key]: value }));
    setDirty(true);
    setSaveState('idle');
  }

  async function persistDraft() {
    setSaveState('saving');
    try {
      const id = await saveAccommodationDraft(user, form, step, draftId, sourceSubmission?.id || '');
      setDraftId(id);
      setDirty(false);
      setSaveState('saved');
      return id;
    } catch (caught) {
      setSaveState('error');
      setError(errorMessage(caught, 'The draft could not be saved.'));
      return '';
    }
  }

  function focusField(id: string) {
    window.requestAnimationFrame(() => document.getElementById(id)?.focus());
  }

  function validate(targetStep: number) {
    const requirements: Record<number, Array<[keyof AccommodationDraftValues, string, string]>> = {
      1: [['name', 'Accommodation name', 'accommodation-name'], ['village', 'Village or town', 'accommodation-village'], ['address', 'Street address', 'accommodation-address'], ['description', 'Description', 'accommodation-description']],
      2: [['stageId', 'Nearest trail stage', 'accommodation-stage'], ['distanceFromTrailKm', 'Distance from trail', 'accommodation-distance']],
      3: [['website', 'Booking website', 'accommodation-website'], ['email', 'Public email', 'accommodation-email'], ['phone', 'Public phone', 'accommodation-phone'], ['priceMinEur', 'Minimum price', 'accommodation-price-min'], ['priceMaxEur', 'Maximum price', 'accommodation-price-max']],
      4: [],
    };
    const missing = requirements[targetStep].find(([key]) => String(form[key]).trim() === '');
    if (missing) { setError(`${missing[1]} is required before continuing.`); focusField(missing[2]); return false; }
    if (targetStep === 2 && Number(form.distanceFromTrailKm) < 0) { setError('Distance from the trail cannot be negative.'); focusField('accommodation-distance'); return false; }
    if (targetStep === 2 && Boolean(form.latitude) !== Boolean(form.longitude)) { setError('Add both latitude and longitude, or leave both blank.'); focusField(form.latitude ? 'accommodation-longitude' : 'accommodation-latitude'); return false; }
    if (targetStep === 3 && Number(form.priceMaxEur) < Number(form.priceMinEur)) { setError('Maximum price must be at least the minimum price.'); focusField('accommodation-price-max'); return false; }
    if (targetStep === 4 && !form.policyAgreement) { setError('Accept the partner listing policy before submitting.'); focusField('accommodation-policy'); return false; }
    setError('');
    return true;
  }

  async function nextStep() {
    if (!validate(step)) return;
    const next = Math.min(4, step + 1);
    setStep(next);
    setDirty(true);
  }

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!validate(1) || !validate(2) || !validate(3) || !validate(4)) return;
    if (catalogBusy || catalogError || !stages.length) { setError('Wait for the trail catalog to load before submitting.'); return; }
    setBusy(true);
    setError('');
    try {
      const selectedTrail = trails.find((row) => row.id === form.trailId);
      const selectedStage = stages.find((row) => row.id === form.stageId);
      await saveSubmission(user, {
        trailId: form.trailId, trailName: selectedTrail?.name || form.trailName,
        stageId: form.stageId, stageName: selectedStage?.name || form.stageName, stageSequence: selectedStage?.sequence ?? form.stageSequence,
        name: form.name.trim(), type: form.type, village: form.village.trim(), address: form.address.trim(), description: form.description.trim(),
        phone: form.phone.trim(), email: form.email.trim(), website: form.website.trim(), whatsapp: form.whatsapp.trim(), googleMapsUrl: form.googleMapsUrl.trim(),
        priceMinEur: Number(form.priceMinEur), priceMaxEur: Number(form.priceMaxEur), distanceFromTrailKm: Number(form.distanceFromTrailKm),
        capacityPeople: form.capacityPeople === '' ? null : Number(form.capacityPeople), monthsOpen: form.monthsOpen.trim(),
        latitude: form.latitude === '' ? null : Number(form.latitude), longitude: form.longitude === '' ? null : Number(form.longitude), policyAgreement: form.policyAgreement,
      }, sourceSubmission || undefined);
      if (draftId) await deleteAccommodationDraft(user, draftId);
      onSubmitted(sourceSubmission?.status === 'approved' ? 'Your update is in review. The current listing remains live until the update is approved.' : 'Your accommodation is in review. We’ll show every status change in this portal.');
    } catch (caught) {
      setError(errorMessage(caught, 'Submission failed.'));
    } finally {
      setBusy(false);
    }
  }

  async function close() {
    if (dirty) await persistDraft();
    onClose();
  }

  return (
    <section className="form-panel wizard-panel" aria-labelledby="wizard-title">
      <div className="panel-heading"><div><p className="eyebrow dark">{sourceSubmission ? 'UPDATE LISTING' : 'ACCOMMODATION DRAFT'}</p><h2 id="wizard-title" ref={headingRef} tabIndex={-1}>{sourceSubmission?.name || form.name || 'List your accommodation'}</h2></div><button className="text-button" type="button" onClick={() => void close()}>Close</button></div>
      {sourceSubmission?.status === 'approved' && <p className="notice info">Your current listing stays live while this update is reviewed.</p>}
      <ol className="wizard-progress" aria-label="Listing progress">{stepLabels.map((label, index) => <li key={label} aria-current={step === index + 1 ? 'step' : undefined} className={step > index + 1 ? 'complete' : ''}><span>{step > index + 1 ? '✓' : index + 1}</span><strong>{label}</strong></li>)}</ol>
      <div className="wizard-status" aria-live="polite"><span>Step {step} of 4</span><span>{saveState === 'saving' ? 'Saving draft…' : saveState === 'saved' ? 'Draft saved' : saveState === 'error' ? 'Draft not saved' : 'Changes autosave'}</span></div>
      {catalogError && <p className="notice error" role="alert">{catalogError}</p>}
      {error && <p className="notice error" role="alert">{error}</p>}
      <form className="wizard-form" onSubmit={submit}>
        {step === 1 && <fieldset><legend>Property details</legend><p>Start with the information hikers use to understand the stay.</p><div className="form-grid">
          <label>Accommodation name<input id="accommodation-name" value={form.name} onChange={(event) => update('name', event.target.value)} required /></label>
          <label>Type<select value={form.type} onChange={(event) => update('type', event.target.value)}>{lodgingTypes.map((type) => <option key={type}>{type}</option>)}</select></label>
          <label>Village or town<input id="accommodation-village" value={form.village} onChange={(event) => update('village', event.target.value)} required /></label>
          <label>Street address<input id="accommodation-address" value={form.address} onChange={(event) => update('address', event.target.value)} required /></label>
          <label className="full">Description<textarea id="accommodation-description" rows={5} maxLength={800} value={form.description} onChange={(event) => update('description', event.target.value)} required /><small>{form.description.length}/800 characters</small></label>
        </div></fieldset>}

        {step === 2 && <fieldset><legend>Trail location and stage</legend><p>Connect the property to the point hikers will recognise.</p><div className="form-grid">
          <label>Trail<select value={form.trailId} onChange={(event) => { setCatalogBusy(true); setCatalogError(''); setStages([]); update('trailId', event.target.value); update('stageId', ''); }} required>{trails.map((trail) => <option key={trail.id} value={trail.id}>{trail.name}</option>)}</select></label>
          <label>Nearest trail stage<select id="accommodation-stage" value={form.stageId} disabled={catalogBusy || Boolean(catalogError)} onChange={(event) => update('stageId', event.target.value)} required><option value="">{catalogBusy ? 'Loading stages…' : 'Select a named point'}</option>{stages.map((stage) => <option key={stage.id} value={stage.id}>{stage.name}</option>)}</select></label>
          <label>Distance from trail (km)<input id="accommodation-distance" type="number" min="0" step="0.1" value={form.distanceFromTrailKm} onChange={(event) => update('distanceFromTrailKm', event.target.value)} required /></label>
          <label>Google Maps link <span>Optional</span><input type="url" value={form.googleMapsUrl} onChange={(event) => update('googleMapsUrl', event.target.value)} placeholder="https://maps.google.com/…" /></label>
          <label>Latitude <span>Optional</span><input id="accommodation-latitude" type="number" min="-90" max="90" step="any" value={form.latitude} onChange={(event) => update('latitude', event.target.value)} /></label>
          <label>Longitude <span>Optional</span><input id="accommodation-longitude" type="number" min="-180" max="180" step="any" value={form.longitude} onChange={(event) => update('longitude', event.target.value)} /></label>
        </div></fieldset>}

        {step === 3 && <fieldset><legend>Contact, pricing and availability</legend><p>EuroTrex sends hikers to the host directly; it does not process bookings or payments.</p><div className="form-grid">
          <label>Booking website<input id="accommodation-website" type="url" value={form.website} onChange={(event) => update('website', event.target.value)} placeholder="https://" required /></label>
          <label>Public email<input id="accommodation-email" type="email" value={form.email} onChange={(event) => update('email', event.target.value)} required /></label>
          <label>Public phone<input id="accommodation-phone" type="tel" value={form.phone} onChange={(event) => update('phone', event.target.value)} required /></label>
          <label>WhatsApp number <span>Optional</span><input type="tel" value={form.whatsapp} onChange={(event) => update('whatsapp', event.target.value)} /></label>
          <label>Minimum nightly price (€)<input id="accommodation-price-min" type="number" min="0" step="1" value={form.priceMinEur} onChange={(event) => update('priceMinEur', event.target.value)} required /></label>
          <label>Maximum nightly price (€)<input id="accommodation-price-max" type="number" min="0" step="1" value={form.priceMaxEur} onChange={(event) => update('priceMaxEur', event.target.value)} required /></label>
          <label>Maximum guests <span>Optional</span><input type="number" min="1" step="1" value={form.capacityPeople} onChange={(event) => update('capacityPeople', event.target.value)} /></label>
          <label>Months open <span>Optional</span><input value={form.monthsOpen} onChange={(event) => update('monthsOpen', event.target.value)} placeholder="e.g. March–November or year-round" /></label>
        </div></fieldset>}

        {step === 4 && <fieldset><legend>Review and submit</legend><p>Check the essentials before this draft enters manual review.</p><div className="review-summary">
          <section><span>Property</span><h3>{form.name}</h3><p>{form.type} · {form.village}<br />{form.address}</p></section>
          <section><span>Trail location</span><h3>{stages.find((row) => row.id === form.stageId)?.name || form.stageName}</h3><p>{form.distanceFromTrailKm} km from the trail</p></section>
          <section><span>Price and booking</span><h3>€{form.priceMinEur}–€{form.priceMaxEur}</h3><p>{form.website}<br />{form.email}</p></section>
          <section className="full"><span>What verified means</span><p>EuroTrex reviews the representative’s authority, contact details and trail relevance before publication. It is not an endorsement or booking guarantee. Pilot fee or commission terms, if any, are confirmed before publication. Review is manual during private testing and has no guaranteed service window.</p></section>
        </div><label className="check-label policy-check"><input id="accommodation-policy" type="checkbox" checked={form.policyAgreement} onChange={(event) => update('policyAgreement', event.target.checked)} required /><span>I confirm that I represent this accommodation, the information is accurate, and I accept the <a href="/partner-terms" target="_blank">partner listing policy</a>.</span></label></fieldset>}

        <div className="wizard-actions"><button type="button" className="text-button" disabled={saveState === 'saving'} onClick={() => void persistDraft()}>{saveState === 'saving' ? 'Saving…' : 'Save draft'}</button><div>{step > 1 && <button type="button" className="button button-secondary" onClick={() => setStep((value) => value - 1)}>Back</button>}{step < 4 ? <button type="button" className="button button-primary" onClick={() => void nextStep()}>Continue</button> : <button className="button button-primary" disabled={busy || catalogBusy || Boolean(catalogError)}>{busy ? 'Submitting…' : sourceSubmission ? 'Submit update' : 'Submit for review'}</button>}</div></div>
      </form>
    </section>
  );
}
