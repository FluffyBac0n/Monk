import type { ReactNode } from 'react';

type InterestFormProps = {
  kind: 'beta' | 'involved';
  defaultInterest?: string;
  compact?: boolean;
  defaultMessage?: string;
  trail?: string;
  partnership?: boolean;
};

const interestOptions = [
  ['volunteer', 'Volunteer and trail checks'],
  ['collaborate', 'Community or public-sector collaboration'],
  ['field-walks', 'Join field walks'],
  ['sponsor', 'Sponsorship and partnerships'],
  ['host', 'Accommodation hosting'],
  ['other', 'Something else'],
  ['report', 'Report a trail information issue'],
];

function RequiredLabel({ children }: { children: ReactNode }) {
  return <span className="field-label">{children} <span className="required-marker" aria-hidden="true">*</span></span>;
}

export function InterestForm({ kind, defaultInterest = 'volunteer', compact = false, defaultMessage = '', trail = 'all', partnership = false }: InterestFormProps) {
  const endpoint = `/api/interest?kind=${kind}${compact ? '&compact=true' : ''}`;
  const feedbackId = `${kind}-interest-feedback${compact ? '-compact' : ''}`;

  return (
    <form
      action={endpoint}
      method="post"
      data-interest-form
      className={`interest-form${compact ? ' compact' : ''}${kind === 'beta' ? ' email-only' : ''}`}
      {...{
        'hx-post': endpoint,
        'hx-target': `#${feedbackId}`,
        'hx-swap': 'innerHTML',
        'hx-select': 'unset',
        'hx-boost': 'false',
        'hx-push-url': 'false',
        'hx-sync': 'this:replace',
        'hx-disabled-elt': 'find button[type="submit"]',
      }}
    >
      <div className="honeypot" aria-hidden="true"><label>Website<input name="website" tabIndex={-1} autoComplete="off" /></label></div>
      {kind === 'beta' && <input type="hidden" name="trail" value={trail} data-notify-trail />}
      {kind === 'involved' && (
        <>
          <label><RequiredLabel>Your name</RequiredLabel><input name="name" autoComplete="name" maxLength={120} required /></label>
          <label>Organisation<input name="organization" autoComplete="organization" maxLength={160} /></label>
          {partnership ? <input type="hidden" name="interest" value="sponsor" /> : <label className="full"><RequiredLabel>How would you like to help?</RequiredLabel>
            <select name="interest" defaultValue={defaultInterest} required>
              {interestOptions.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </label>}
        </>
      )}
      <label><RequiredLabel>Email address</RequiredLabel><input name="email" type="email" autoComplete="email" maxLength={254} required /></label>
      {kind === 'involved' && <label className="full"><RequiredLabel>{partnership ? 'Your proposed contribution' : 'Tell us a little more'}</RequiredLabel><textarea name="message" rows={4} maxLength={1500} defaultValue={defaultMessage} required /></label>}
      {kind === 'involved' && <><p className="form-privacy full">We use these details to respond to your enquiry. Read our <a href="/privacy" target="_blank" rel="noopener">privacy notice</a>.</p><label className="check-label full"><input name="consent" value="yes" type="checkbox" /><span>Also email me occasional EuroTrex project updates. This is optional.</span></label></>}
      <div id={feedbackId} className="form-feedback full" aria-live="polite" />
      <button type="submit" className={`button ${kind === 'beta' ? 'button-yellow' : 'button-primary'} full`}>
        <span className="submit-idle">{kind === 'beta' ? 'Notify Me' : partnership ? 'Send partnership enquiry' : 'Send my interest'}</span>
        <span className="submit-loading">Sending…</span>
      </button>
      {kind === 'beta' && <p className="beta-privacy full"><span>We’ll use your email for the selected EuroTrex trail and app updates.</span><span>Read our <a href="/privacy" target="_blank" rel="noopener">privacy notice</a>.</span></p>}
    </form>
  );
}
