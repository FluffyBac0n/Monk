'use client';

import type { ReactNode } from 'react';

type InterestFormProps = {
  kind: 'beta' | 'involved';
  defaultInterest?: string;
  compact?: boolean;
};

const interestOptions = [
  ['volunteer', 'Volunteer and trail checks'],
  ['collaborate', 'Community or public-sector collaboration'],
  ['field-walks', 'Join field walks'],
  ['sponsor', 'Sponsorship and partnerships'],
  ['host', 'Accommodation hosting'],
  ['other', 'Something else'],
];

function RequiredLabel({ children }: { children: ReactNode }) {
  return <span className="field-label">{children} <span className="required-marker" aria-hidden="true">*</span></span>;
}

export function InterestForm({ kind, defaultInterest = 'volunteer', compact = false }: InterestFormProps) {
  const endpoint = `/api/interest?kind=${kind}${compact ? '&compact=true' : ''}`;

  return (
    <form
      action={endpoint}
      method="post"
      data-interest-form
      className={`interest-form${compact ? ' compact' : ''}`}
      {...{
        'hx-post': endpoint,
        'hx-swap': 'none',
        'hx-boost': 'false',
        'hx-push-url': 'false',
        'hx-disabled-elt': 'find button[type="submit"]',
      }}
    >
      <div className="honeypot" aria-hidden="true"><label>Website<input name="website" tabIndex={-1} autoComplete="off" /></label></div>
      {kind === 'involved' && (
        <>
          <label><RequiredLabel>Your name</RequiredLabel><input name="name" autoComplete="name" maxLength={120} required /></label>
          <label>Organisation<input name="organization" autoComplete="organization" maxLength={160} /></label>
          <label className="full"><RequiredLabel>How would you like to help?</RequiredLabel>
            <select name="interest" defaultValue={defaultInterest} required>
              {interestOptions.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </label>
        </>
      )}
      <label><RequiredLabel>Email address</RequiredLabel><input name="email" type="email" autoComplete="email" maxLength={254} required /></label>
      {kind === 'beta' && (
        <label><RequiredLabel>Preferred platform</RequiredLabel>
          <select name="platform" defaultValue="ios" required>
            <option value="ios">iPhone / iOS</option>
            <option value="android">Android</option>
            <option value="both">Both</option>
            <option value="not-sure">Not sure yet</option>
          </select>
        </label>
      )}
      {kind === 'involved' && <label className="full"><RequiredLabel>Tell us a little more</RequiredLabel><textarea name="message" rows={5} maxLength={1500} required /></label>}
      {kind === 'involved' && <label className="check-label full"><input name="consent" value="yes" type="checkbox" required /><span>EuroTrex may use these details to reply and send relevant project updates. See the <a href="/privacy" target="_blank">privacy notice</a>. <span className="required-marker" aria-hidden="true">*</span></span></label>}
      <div className="form-feedback full" aria-live="polite" />
      <button type="submit" className="button button-yellow full">
        <span className="submit-idle">{kind === 'beta' ? 'Notify me' : 'Send my interest'}</span>
        <span className="submit-loading">Sending…</span>
      </button>
      {kind === 'beta' && <p className="beta-privacy full">We’ll only use your email for EuroTrex app updates. Read our <a href="/privacy" target="_blank">privacy notice</a>.</p>}
    </form>
  );
}
