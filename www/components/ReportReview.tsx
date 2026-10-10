'use client';
import {useEffect, useState} from 'react';
import {ReportSelect} from './ReportSelect';
import {reviewReport, type TrailReport, type ReportEvent} from '@/lib/trail-reports';

export const reportStatusLabels: Record<string, string> = {new: 'Received', reviewed: 'Reviewed', forwarded: 'Sent', resolved: 'Resolved', duplicate: 'Duplicate', dismissed: 'Dismissed'};
const steps = ['new', 'reviewed', 'forwarded', 'resolved'];
const guidance: Record<string, string> = {
  new: 'Check the location, description and photos, then mark the report as reviewed.',
  reviewed: 'Forward the report to an authority and record it as sent, or resolve it directly if the work is complete.',
  forwarded: 'Follow up with the authority. Add progress notes and mark resolved once the work is confirmed.',
  resolved: 'Work is complete. Reopen the review if the problem needs more attention.',
  duplicate: 'This problem is tracked in the linked original report.',
  dismissed: 'No further action is planned. The reason is recorded in the activity below.',
};
export function ReportProgress({report, events}: {report: TrailReport; events: ReportEvent[]}) {
  const reached = new Set(['new', report.status, ...events.map(e => e.status), ...events.map(e => e.previousStatus)]);
  return <section className="report-progress" aria-label="Report workflow">
    <div className="report-progress-title"><strong>Report progress</strong><span className={`report-status status-${report.status}`}>{reportStatusLabels[report.status] || report.status}</span></div>
    <ol className="report-progress-steps">{steps.map((step, index) => <li key={step} className={`${reached.has(step) ? 'reached' : ''} ${report.status === step ? 'current' : ''}`} aria-current={report.status === step ? 'step' : undefined}><span aria-hidden="true">{reached.has(step) && report.status !== step ? '✓' : index + 1}</span><strong>{reportStatusLabels[step]}</strong>{step === 'forwarded' && <small>When needed</small>}</li>)}</ol>
    <p>{guidance[report.status]}</p>
    <button type="button" className="button button-secondary report-next-step-link" onClick={() => {const review = document.getElementById(`review-${report.id}`); review?.scrollIntoView({behavior: 'smooth', block: 'start'}); review?.focus({preventScroll: true});}}>Review & next step ↓</button>
    {report.status === 'duplicate' && report.duplicateOf && <p>Original report: <strong>{report.duplicateOf}</strong></p>}
    {report.authority && <p className="report-forwarded-to"><strong>Authority:</strong> {report.authority}{report.forwardingReference && ` · ${report.forwardingReference}`}</p>}
  </section>;
}

type Action = 'review' | 'forward' | 'resolve' | 'note' | 'dismiss' | 'duplicate' | 'reopen';
const actions: Record<Action, {label: string; button: string; status?: string; explanation: string}> = {
  review: {label: 'Review', button: 'Mark reviewed', status: 'reviewed', explanation: 'Confirm you have checked the report and set its priority.'},
  forward: {label: 'Record sending', button: 'Mark as sent', status: 'forwarded', explanation: 'Send the printable report through your usual email or channel, then record the recipient here. Mark as sent records your action; it does not send an email.'},
  resolve: {label: 'Resolve', button: 'Mark resolved', status: 'resolved', explanation: 'Describe the work completed or how you confirmed the problem has been fixed.'},
  note: {label: 'Update details', button: 'Save changes', explanation: 'Add a progress note or update the priority. The current status is kept.'},
  dismiss: {label: 'Dismiss', button: 'Dismiss report', status: 'dismissed', explanation: 'Explain why this report needs no further action.'},
  duplicate: {label: 'Link duplicate', button: 'Link duplicate', status: 'duplicate', explanation: 'Enter the reference of the original report for the same trail.'},
  reopen: {label: 'Reopen review', button: 'Reopen review', status: 'reviewed', explanation: 'Explain why the report needs another review.'},
};
const nextAction = (status: string): Action => status === 'new' ? 'review' : status === 'reviewed' ? 'forward' : 'note';
export function ReportReview({report, onSaved}: {report: TrailReport; onSaved: (message: string) => void}) {
  const [base, setBase] = useState(report), [dirty, setDirty] = useState(false);
  const [action, setAction] = useState<Action>(() => nextAction(report.status));
  const [priority, setPriority] = useState(report.priority), [authority, setAuthority] = useState(report.authority);
  const [reference, setReference] = useState(report.forwardingReference), [duplicate, setDuplicate] = useState(report.duplicateOf || '');
  const [note, setNote] = useState(''), [error, setError] = useState(''), [busy, setBusy] = useState(false), [message, setMessage] = useState('');
  function reset(next: TrailReport) {setBase(next); setPriority(next.priority); setAuthority(next.authority); setReference(next.forwardingReference); setDuplicate(next.duplicateOf || ''); setNote(''); setAction(nextAction(next.status)); setDirty(false);}
  useEffect(() => {if (!dirty) reset(report);}, [report, dirty]);
  const stale = dirty && base.updatedAt.toMillis() !== report.updatedAt.toMillis();
  const closed = ['resolved', 'dismissed', 'duplicate'].includes(base.status);
  const targetStatus = actions[action].status || base.status;
  const noteRequired = ['resolved', 'dismissed'].includes(targetStatus) || action === 'reopen';
  const choices: Action[] = closed ? ['reopen', 'note'] : [...(base.status === 'new' ? ['review' as Action] : []), 'forward', 'resolve', 'note'];
  function choose(next: Action) {setAction(next); setDirty(true); setError(''); setMessage('');}
  return <section id={`review-${report.id}`} tabIndex={-1} className="report-review-workflow" aria-label="Review and next step">
    <div className="report-review-heading"><div><p className="eyebrow">NEXT STEP</p><h3>Review & follow-up</h3></div><span className={`report-status status-${report.status}`}>{reportStatusLabels[report.status]}</span></div>
    <div className="report-action-choices" role="group" aria-label="Choose report action">{choices.map(key => <button key={key} type="button" className={`button ${action === key ? 'button-primary' : 'button-secondary'}`} aria-pressed={action === key} disabled={busy} onClick={() => choose(key)}>{actions[key].label}</button>)}</div>
    {!closed && <details className="report-other-outcomes"><summary>Other outcomes</summary><div className="report-action-choices">{(['duplicate', 'dismiss'] as Action[]).map(key => <button key={key} type="button" className={`button ${action === key ? 'button-primary' : 'button-secondary'}`} aria-pressed={action === key} disabled={busy} onClick={() => choose(key)}>{actions[key].label}</button>)}</div></details>}
    <form className="form-grid single report-action-form" onChange={() => setDirty(true)} onSubmit={async event => {
      event.preventDefault(); if (busy || stale) return;
      setBusy(true); setError(''); setMessage('');
      try {
        await reviewReport(base, {status: targetStatus, priority, authority, forwardingReference: reference, duplicateOf: duplicate, note});
        const saved = targetStatus === base.status ? 'Report details saved.' : `Report updated: ${reportStatusLabels[base.status]} → ${reportStatusLabels[targetStatus]}.`;
        setDirty(false); setNote(''); setMessage(saved); onSaved(saved);
      } catch (error) {setError(error instanceof Error ? error.message : 'Could not save the review. Please retry.');}
      finally {setBusy(false);}
    }}>
      <p className="report-action-explanation">{actions[action].explanation}</p>
      <ReportSelect label="Priority" value={priority} disabled={busy} onChange={value => {setPriority(value); setDirty(true);}} options={['normal', 'high', 'urgent'].map(value => ({value, label: value.charAt(0).toUpperCase() + value.slice(1)}))} />
      {action === 'forward' && <div className="report-forward-fields"><label>Sent to / responsible authority<input value={authority} disabled={busy} maxLength={200} required onChange={e => setAuthority(e.target.value)} placeholder="Authority, team or recipient" /></label><label>Sending reference (optional)<input value={reference} disabled={busy} maxLength={300} onChange={e => setReference(e.target.value)} placeholder="Email address, case reference or date sent" /></label><p className="report-helper">The time you record this and your account are saved in the activity history.</p></div>}
      {action === 'duplicate' && <label>Original report reference<input value={duplicate} disabled={busy} required onChange={e => setDuplicate(e.target.value)} /></label>}
      <label>{action === 'resolve' ? 'Resolution note' : action === 'dismiss' ? 'Reason for dismissal' : action === 'reopen' ? 'Reason for reopening' : 'Internal note'}{!noteRequired && ' (optional)'}<textarea value={note} disabled={busy} maxLength={1500} required={noteRequired} rows={3} onChange={e => setNote(e.target.value)} /></label>
      {stale && <div className="notice" role="alert"><p>Another reviewer updated this report. Copy any notes you want to keep, then load the latest review.</p><button type="button" className="button button-secondary" onClick={() => reset(report)}>Discard edits and load latest</button></div>}
      <div className="report-transition-confirm"><span>{reportStatusLabels[base.status]}{targetStatus !== base.status && <> <span aria-hidden="true">→</span> <strong>{reportStatusLabels[targetStatus]}</strong></>}</span><button className="button button-primary" disabled={busy || stale}>{busy ? 'Saving…' : actions[action].button}</button></div>
    </form>
    {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
  </section>;
}
