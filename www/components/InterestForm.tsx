'use client';

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
          <label>Your name<input name="name" autoComplete="name" maxLength={120} required /></label>
          <label>Organisation <span>Optional</span><input name="organization" autoComplete="organization" maxLength={160} /></label>
          <label className="full">How would you like to help?
            <select name="interest" defaultValue={defaultInterest} required>
              {interestOptions.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </label>
        </>
      )}
      <label>Email address<input name="email" type="email" autoComplete="email" maxLength={254} required /></label>
      {kind === 'beta' && (
        <label>Preferred platform
          <select name="platform" defaultValue="ios" required>
            <option value="ios">iPhone / iOS</option>
            <option value="android">Android</option>
            <option value="both">Both</option>
            <option value="not-sure">Not sure yet</option>
          </select>
        </label>
      )}
      {kind === 'involved' && <label className="full">Tell us a little more<textarea name="message" rows={5} maxLength={1500} required /></label>}
      {kind === 'involved' && <label className="check-label full"><input name="consent" value="yes" type="checkbox" required /><span>EuroTrex may use these details to reply and send relevant project updates. See the <a href="/privacy" target="_blank">privacy notice</a>.</span></label>}
      <div className="form-feedback full" aria-live="polite" />
      <button type="submit" className="button button-yellow full">
        <span className="submit-idle">{kind === 'beta' ? 'Notify me' : 'Send my interest'}</span>
        <span className="submit-loading">Sending…</span>
      </button>
      {kind === 'beta' && <p className="beta-privacy full">We’ll only use your email for EuroTrex app updates. Read our <a href="/privacy" target="_blank">privacy notice</a>.</p>}
    </form>
  );
}
