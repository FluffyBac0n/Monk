'use client';

import type { User } from 'firebase/auth';
import { FormEvent, type ReactNode, useEffect, useRef, useState } from 'react';
import {
  deleteAccommodationDraft,
  listStages,
  listTrails,
  saveAccommodationDraft,
  saveSubmission,
} from '@/lib/accommodations';
import type { AccommodationDraftValues, AccommodationSubmission, StageOption, TrailOption } from '@/lib/models';
import { submissionHasPublishedVersion } from '@/lib/models';

const lodgingTypes = ['Hotel', 'Guesthouse', 'Hostel', 'Apartment', 'Villa', 'Camping'];
const stepLabels = ['Property details', 'Trail and stage point', 'Contact and pricing', 'Review and submit'];

function RequiredLabel({ children }: { children: ReactNode }) {
  return <span className="field-label">{children} <span className="required-marker" aria-hidden="true">*</span></span>;
}

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

function validWebUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function MobileAccommodationPreview({ form, stageName }: { form: AccommodationDraftValues; stageName: string }) {
  const latitude = Number(form.latitude);
  const longitude = Number(form.longitude);
  const hasCoordinates = form.latitude.trim() !== '' && form.longitude.trim() !== ''
    && Number.isFinite(latitude) && latitude >= -90 && latitude <= 90
    && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;
  const hasPhone = form.phone.replace(/\D/g, '').length >= 6;
  const hasEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email.trim());
  const hasBookingUrl = validWebUrl(form.website.trim());
  const markerIcon: Record<string, string> = {
    Hotel: 'H', Guesthouse: '⌂', Hostel: '▣', Apartment: '⌂', Villa: '⌂', Camping: '△',
  };
  const priceMin = form.priceMinEur.trim() === '' ? null : Number(form.priceMinEur);
  const priceMax = form.priceMaxEur.trim() === '' ? null : Number(form.priceMaxEur);
  const price = priceMin == null && priceMax == null
    ? ''
    : priceMin === 0 && priceMax === 0
      ? 'Free'
      : priceMin != null && priceMax != null && priceMin !== priceMax
        ? `€${priceMin}–€${priceMax}`
        : `€${priceMin ?? priceMax}`;
  const facts = [
    price ? { icon: '€', label: 'Nightly price', value: price } : null,
    form.monthsOpen.trim() ? { icon: '▦', label: 'Season', value: form.monthsOpen.trim() } : null,
    form.capacityPeople.trim() ? { icon: '●', label: 'Capacity', value: `${form.capacityPeople} guests` } : null,
  ].filter((fact): fact is { icon: string; label: string; value: string } => Boolean(fact));
  const whatsapp = form.whatsapp.trim();
  const showWhatsapp = whatsapp && whatsapp.replace(/\D/g, '') !== form.phone.replace(/\D/g, '');
  const distance = form.distanceFromTrailKm.trim() === '' ? null : Number(form.distanceFromTrailKm);
  const distanceIsNear = distance != null && distance < 0.5;

  const actions = [
    { icon: '⌖', label: hasCoordinates ? 'Map available' : 'Map unavailable', available: hasCoordinates },
    { icon: '☎', label: hasPhone ? `Phone: ${form.phone}` : 'Phone unavailable', available: hasPhone },
    { icon: '✉', label: hasEmail ? `Email: ${form.email}` : 'Email unavailable', available: hasEmail },
  ];

  return (
    <section className="mobile-preview" aria-labelledby="mobile-preview-title">
      <div className="mobile-preview-heading">
        <div><p className="eyebrow dark">MOBILE APP PREVIEW</p><h3 id="mobile-preview-title">How hikers will see it.</h3></div>
        <span>Preview only</span>
      </div>
      <div className="mobile-preview-canvas">
        <div className="mobile-preview-context"><span>ACCOMMODATION</span><strong>{form.trailName || 'Trail'} · {stageName || 'Stage point'}</strong></div>
        <article className="mobile-accommodation-card">
          <header className="mobile-card-header">
            <span className={`mobile-type-marker ${form.type === 'Camping' ? 'camping' : ''}`} aria-hidden="true">{markerIcon[form.type] || '⌂'}</span>
            <div className="mobile-card-title"><strong>{form.name.trim() || 'Accommodation'}</strong>{form.type && <span>{form.type}</span>}</div>
            {distance != null && Number.isFinite(distance) && <span className={`mobile-card-distance ${distanceIsNear ? 'near' : ''}`}>⌖ {distance.toFixed(1)} km</span>}
          </header>
          <div className="mobile-card-actions" aria-label="Contact availability">{actions.map((action) => <span className={action.available ? 'available' : ''} key={action.label} title={action.label} aria-label={action.label} role="img">{action.icon}</span>)}</div>
          {facts.length > 0 && <div className="mobile-card-facts">{facts.map((fact, index) => <div key={fact.label}>{index > 0 && <i aria-hidden="true">|</i>}<span aria-hidden="true">{fact.icon}</span><p><small>{fact.label}</small><strong>{fact.value}</strong></p></div>)}</div>}
          {!hasCoordinates && (form.address.trim() || form.village.trim()) && <p className="mobile-card-detail"><span aria-hidden="true">⌖</span>{[form.address.trim(), form.village.trim()].filter(Boolean).join(' · ')}</p>}
          {showWhatsapp && <p className="mobile-card-detail"><span aria-hidden="true">◉</span>WhatsApp: {whatsapp}</p>}
          {hasBookingUrl && <div className="mobile-card-book"><span>↗</span> Book</div>}
        </article>
      </div>
      <div className="mobile-preview-notes">
        {!hasCoordinates && <p>Add latitude and longitude to enable the map button.</p>}
        <p>Your description is reviewed by EuroTrex but is not currently shown on this app card.</p>
      </div>
    </section>
  );
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
    }).catch((caught) => { if (active) setCatalogError(errorMessage(caught, 'Trail stage points could not be loaded.')); }).finally(() => { if (active) setCatalogBusy(false); });
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
      2: [['stageId', 'Nearest stage point', 'accommodation-stage'], ['distanceFromTrailKm', 'Distance from trail', 'accommodation-distance']],
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
      onSubmitted(sourceSubmission && submissionHasPublishedVersion(sourceSubmission) ? 'Your update is in review. The live version remains available until the update is approved.' : 'Your listing is in review. We’ll show every status change in this portal.');
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
      <div className="panel-heading"><div><p className="eyebrow dark">{sourceSubmission ? 'UPDATE LISTING' : 'PROPERTY DRAFT'}</p><h2 id="wizard-title" ref={headingRef} tabIndex={-1}>{sourceSubmission?.name || form.name || 'List your property'}</h2></div><button className="text-button" type="button" onClick={() => void close()}>Close</button></div>
      {sourceSubmission && submissionHasPublishedVersion(sourceSubmission) && <p className="notice info">The live version remains available while this update is reviewed.</p>}
      <ol className="wizard-progress" aria-label="Listing progress">{stepLabels.map((label, index) => <li key={label} aria-current={step === index + 1 ? 'step' : undefined} className={step > index + 1 ? 'complete' : ''}><span>{step > index + 1 ? '✓' : index + 1}</span><strong>{label}</strong></li>)}</ol>
      <div className="wizard-status" aria-live="polite"><span>Step {step} of 4</span><span>{saveState === 'saving' ? 'Saving draft…' : saveState === 'saved' ? 'Draft saved' : saveState === 'error' ? 'Draft not saved' : 'Changes autosave'}</span></div>
      {catalogError && <p className="notice error" role="alert">{catalogError}</p>}
      {error && <p className="notice error" role="alert">{error}</p>}
      <form className="wizard-form" onSubmit={submit}>
        {step === 1 && <fieldset><legend>Property details</legend><p>Start with the information hikers use to understand the accommodation.</p><div className="form-grid">
          <label><RequiredLabel>Accommodation name</RequiredLabel><input id="accommodation-name" value={form.name} onChange={(event) => update('name', event.target.value)} required /></label>
          <label><RequiredLabel>Type</RequiredLabel><select value={form.type} onChange={(event) => update('type', event.target.value)} required>{lodgingTypes.map((type) => <option key={type}>{type}</option>)}</select></label>
          <label><RequiredLabel>Village or town</RequiredLabel><input id="accommodation-village" value={form.village} onChange={(event) => update('village', event.target.value)} required /></label>
          <label><RequiredLabel>Street address</RequiredLabel><input id="accommodation-address" value={form.address} onChange={(event) => update('address', event.target.value)} required /></label>
          <label className="full"><RequiredLabel>Description</RequiredLabel><textarea id="accommodation-description" rows={5} maxLength={800} value={form.description} onChange={(event) => update('description', event.target.value)} required /><small>{form.description.length}/800 characters</small></label>
        </div></fieldset>}

        {step === 2 && <fieldset><legend>Trail and stage point</legend><p>Connect the property to the named point hikers will recognise.</p><div className="form-grid">
          <label><RequiredLabel>Trail</RequiredLabel><select value={form.trailId} onChange={(event) => { setCatalogBusy(true); setCatalogError(''); setStages([]); update('trailId', event.target.value); update('stageId', ''); }} required>{trails.map((trail) => <option key={trail.id} value={trail.id}>{trail.name}</option>)}</select></label>
          <label><RequiredLabel>Nearest stage point</RequiredLabel><select id="accommodation-stage" value={form.stageId} disabled={catalogBusy || Boolean(catalogError)} onChange={(event) => update('stageId', event.target.value)} required><option value="">{catalogBusy ? 'Loading stage points…' : 'Select a stage point'}</option>{stages.map((stage) => <option key={stage.id} value={stage.id}>{stage.name}</option>)}</select></label>
          <label><RequiredLabel>Distance from trail (km)</RequiredLabel><input id="accommodation-distance" type="number" min="0" step="0.1" value={form.distanceFromTrailKm} onChange={(event) => update('distanceFromTrailKm', event.target.value)} required /></label>
          <label>Google Maps link<input type="url" value={form.googleMapsUrl} onChange={(event) => update('googleMapsUrl', event.target.value)} placeholder="https://maps.google.com/…" /></label>
          <label>Latitude<input id="accommodation-latitude" type="number" min="-90" max="90" step="any" value={form.latitude} onChange={(event) => update('latitude', event.target.value)} /></label>
          <label>Longitude<input id="accommodation-longitude" type="number" min="-180" max="180" step="any" value={form.longitude} onChange={(event) => update('longitude', event.target.value)} /></label>
        </div></fieldset>}

        {step === 3 && <fieldset><legend>Contact, pricing and availability</legend><p>EuroTrex sends hikers to the host directly; it does not process bookings or payments.</p><div className="form-grid">
          <label><RequiredLabel>Booking website</RequiredLabel><input id="accommodation-website" type="url" value={form.website} onChange={(event) => update('website', event.target.value)} placeholder="https://" required /></label>
          <label><RequiredLabel>Public email</RequiredLabel><input id="accommodation-email" type="email" value={form.email} onChange={(event) => update('email', event.target.value)} required /></label>
          <label><RequiredLabel>Public phone</RequiredLabel><input id="accommodation-phone" type="tel" value={form.phone} onChange={(event) => update('phone', event.target.value)} required /></label>
          <label>WhatsApp number<input type="tel" value={form.whatsapp} onChange={(event) => update('whatsapp', event.target.value)} /></label>
          <label><RequiredLabel>Minimum nightly price (€)</RequiredLabel><input id="accommodation-price-min" type="number" min="0" step="1" value={form.priceMinEur} onChange={(event) => update('priceMinEur', event.target.value)} required /></label>
          <label><RequiredLabel>Maximum nightly price (€)</RequiredLabel><input id="accommodation-price-max" type="number" min="0" step="1" value={form.priceMaxEur} onChange={(event) => update('priceMaxEur', event.target.value)} required /></label>
          <label>Maximum guests<input type="number" min="1" step="1" value={form.capacityPeople} onChange={(event) => update('capacityPeople', event.target.value)} /></label>
          <label>Months open<input value={form.monthsOpen} onChange={(event) => update('monthsOpen', event.target.value)} placeholder="e.g. March–November or year-round" /></label>
        </div></fieldset>}

        {step === 4 && <fieldset><legend>Review and submit</legend><p>Preview the app card, then confirm the listing before it enters manual review.</p><MobileAccommodationPreview form={form} stageName={stages.find((row) => row.id === form.stageId)?.name || form.stageName} /><div className="review-summary">
          <section><span>Listing context</span><h3>{form.trailName || 'Trail'} · {stages.find((row) => row.id === form.stageId)?.name || form.stageName}</h3><p>{form.distanceFromTrailKm} km from the trail. This stage point links the listing to the correct place in the app.</p></section>
          <section className="full"><span>What verified means</span><p>EuroTrex reviews the representative’s authority, contact details and trail relevance before publication. It is not an endorsement or booking guarantee. Pilot fee or commission terms, if any, are confirmed before publication. Review is manual during private testing and has no guaranteed service window.</p></section>
        </div><label className="check-label policy-check"><input id="accommodation-policy" type="checkbox" checked={form.policyAgreement} onChange={(event) => update('policyAgreement', event.target.checked)} required /><span>I confirm that I represent this accommodation, the information is accurate, and I accept the <a href="/partner-terms" target="_blank">partner listing policy</a>. <span className="required-marker" aria-hidden="true">*</span></span></label></fieldset>}

        <div className="wizard-actions"><button type="button" className="text-button" disabled={saveState === 'saving'} onClick={() => void persistDraft()}>{saveState === 'saving' ? 'Saving…' : 'Save draft'}</button><div>{step > 1 && <button type="button" className="button button-secondary" onClick={() => setStep((value) => value - 1)}>Back</button>}{step < 4 ? <button type="button" className="button button-primary" onClick={() => void nextStep()}>Continue</button> : <button className="button button-primary" disabled={busy || catalogBusy || Boolean(catalogError)}>{busy ? 'Submitting…' : sourceSubmission ? 'Submit update' : 'Submit for review'}</button>}</div></div>
      </form>
    </section>
  );
}
