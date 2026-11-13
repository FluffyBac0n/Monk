'use client';
import {useEffect, useState} from 'react';
import {useIncidentDraft} from './IncidentDrafts';
import {ReportSelect} from './ReportSelect';
import {ReportWorkflowDialog} from './ReportWorkflowDialog';
import {reviewReport, type TrailReport} from '@/lib/trail-reports';

export const reportStatusLabels: Record<string, string> = {new: 'Received', reviewed: 'Reviewed', forwarded: 'Sent', resolved: 'Resolved', duplicate: 'Duplicate', dismissed: 'Dismissed'};
type Action = 'review' | 'forward' | 'resolve' | 'note' | 'dismiss' | 'duplicate' | 'reopen';
const actions: Record<Action, {label: string; button: string; status?: string; explanation: string}> = {
  review: {label: 'Review', button: 'Approve issue', status: 'reviewed', explanation: 'Confirm the issue and its priority.'},
  forward: {label: 'Record sending', button: 'Mark as sent', status: 'forwarded', explanation: 'Send the printable report through your usual email or channel, then record the recipient here. Mark as sent records your action; it does not send an email.'},
  resolve: {label: 'Resolve', button: 'Mark resolved', status: 'resolved', explanation: 'Describe the work completed or how you confirmed the problem has been fixed. Resolving removes the warning from the mobile trail map.'},
  note: {label: 'Update details', button: 'Save changes', explanation: 'Add a progress note or update the priority. The current status is kept.'},
  dismiss: {label: 'Dismiss', button: 'Dismiss report', status: 'dismissed', explanation: 'Explain why this report needs no further action.'},
  duplicate: {label: 'Link duplicate', button: 'Link duplicate', status: 'duplicate', explanation: 'Enter the reference of the original report for the same trail.'},
  reopen: {label: 'Reopen review', button: 'Reopen review', status: 'reviewed', explanation: 'Explain why the issue is active again.'},
};
type ReviewDraft = {base: TrailReport; action: Action | ''; priority: string; authority: string; publicWarning: boolean; reference: string; duplicate: string; note: string; noteOpen: boolean};
export function ReportReview({report, onSaved}: {report: TrailReport; onSaved: (message: string) => void}) {
  const draft = useIncidentDraft<ReviewDraft>(`review:${report.trailId}:${report.id}`);
  const [initial] = useState(() => draft.read());
  const [workflowOpen, setWorkflowOpen] = useState(false);
  const [base, setBase] = useState(initial?.base || report), [dirty, setDirty] = useState(!!initial);
  const [action, setAction] = useState<Action | ''>(initial?.action || '');
  const [priority, setPriority] = useState(initial?.priority || report.priority), [authority, setAuthority] = useState(initial?.authority ?? report.authority);
  const [publicWarning, setPublicWarning] = useState(initial?.publicWarning ?? report.publicWarning ?? ['reviewed', 'forwarded'].includes(report.status));
  const [reference, setReference] = useState(initial?.reference ?? report.forwardingReference), [duplicate, setDuplicate] = useState(initial?.duplicate ?? report.duplicateOf ?? '');
  const [note, setNote] = useState(initial?.note || ''), [noteOpen, setNoteOpen] = useState(initial?.noteOpen || false);
  const [error, setError] = useState(''), [busy, setBusy] = useState(false);
  function reset(next: TrailReport) {setBase(next); setPriority(next.priority); setAuthority(next.authority); setPublicWarning(next.publicWarning ?? ['reviewed', 'forwarded'].includes(next.status)); setReference(next.forwardingReference); setDuplicate(next.duplicateOf || ''); setNote(''); setNoteOpen(false); setAction(''); setDirty(false); draft.clear();}
  useEffect(() => {if (!dirty) reset(report);}, [report, dirty]);
  useEffect(() => {
    if (dirty) draft.save({base, action, priority, authority, publicWarning, reference, duplicate, note, noteOpen});
    else draft.clear();
  }, [draft, dirty, base, action, priority, authority, publicWarning, reference, duplicate, note, noteOpen]);
  const stale = dirty && base.updatedAt.toMillis() !== report.updatedAt.toMillis();
  const closed = ['resolved', 'dismissed', 'duplicate'].includes(base.status);
  const targetStatus = (action && actions[action].status) || base.status;
  const canDisplayWarning = ['reviewed', 'forwarded'].includes(targetStatus);
  const noteRequired = ['resolved', 'dismissed'].includes(targetStatus) || action === 'reopen';
  const choices: Action[] = closed ? ['reopen', 'note'] : [...(base.status === 'new' ? ['review' as Action] : []), 'forward', 'resolve', 'duplicate', 'dismiss', 'note'];
  function choose(next: Action | '') {setAction(next); setDirty(true); setError('');}
  return <section id={`review-${report.id}`} tabIndex={-1} className="report-review-workflow" aria-label="Next Steps">
    <div className="report-review-toolbar">
      <div className="report-transition-controls">
        <ReportSelect inlineLabel label="Next Steps" value={action} disabled={busy} onChange={value => choose(value as Action | '')} options={[{value:'', label:'Choose action'}, ...choices.map(key => ({value:key, label: key === 'note' ? 'Update details' : actions[key].status === base.status ? 'Update sending details' : `${reportStatusLabels[base.status]} → ${reportStatusLabels[actions[key].status!]}`}))]}/>
        <button type="button" className="text-button report-workflow-link" aria-haspopup="dialog" onClick={() => setWorkflowOpen(true)}>View workflow</button>
      </div>
    </div>
    <ReportWorkflowDialog open={workflowOpen} onClose={() => setWorkflowOpen(false)}/>
    {action && <form className="form-grid single report-action-form" onChange={() => setDirty(true)} onSubmit={async event => {
      event.preventDefault(); if (busy || stale || !action) return;
      setBusy(true); setError('');
      try {
        const publishWarning = canDisplayWarning && publicWarning;
        await reviewReport(base, {status: targetStatus, priority, authority, forwardingReference: reference, duplicateOf: duplicate, note, publicWarning: publishWarning});
        const saved = targetStatus === base.status ? 'Changes saved.' : `${reportStatusLabels[base.status]} → ${reportStatusLabels[targetStatus]}. Saved.`;
        draft.clear(); setDirty(false); setNote(''); setAction(''); onSaved(saved);
      } catch (error) {setError(error instanceof Error ? error.message : 'Could not save the review. Please retry.');}
      finally {setBusy(false);}
    }}>
      {action === 'forward' && <p className="report-action-explanation">Send the report through your usual channel, then record it here.</p>}
      {['review', 'reopen', 'note'].includes(action) && <ReportSelect label="Priority" value={priority} disabled={busy} onChange={value => {setPriority(value); setDirty(true);}} options={['normal', 'high', 'urgent'].map(value => ({value, label: value.charAt(0).toUpperCase() + value.slice(1)}))} />}
      {canDisplayWarning && <div className="report-public-warning">
        <label className="checkbox-row"><input type="checkbox" checked={publicWarning} disabled={busy} aria-describedby={`public-warning-help-${report.id}`} onChange={event => {setPublicWarning(event.target.checked); setDirty(true);}} />Approved for public display</label>
        <p id={`public-warning-help-${report.id}`} className="report-helper">Show the incident’s location and description on the mobile trail map when saved.</p>
      </div>}
      {action === 'forward' && <div className="report-forward-fields"><label>Sent to / responsible authority<input value={authority} disabled={busy} maxLength={200} required onChange={e => setAuthority(e.target.value)} placeholder="Authority, team or recipient" /></label><label>Sending reference (optional)<input value={reference} disabled={busy} maxLength={300} onChange={e => setReference(e.target.value)} placeholder="Email address, case reference or date sent" /></label></div>}
      {action === 'duplicate' && <label>Original report reference<input value={duplicate} disabled={busy} required onChange={e => setDuplicate(e.target.value)} /></label>}
      {(noteRequired || action === 'note' || noteOpen || note) ? <label>{action === 'resolve' ? 'Resolution note' : action === 'dismiss' ? 'Reason for dismissal' : action === 'reopen' ? 'Reason for reopening' : 'Internal note'}{!noteRequired && ' (optional)'}<textarea value={note} disabled={busy} maxLength={1500} required={noteRequired} rows={3} onChange={e => {setNote(e.target.value); setDirty(true);}} /></label> : <button type="button" className="text-button report-add-note" onClick={() => setNoteOpen(true)}>+ Add internal note</button>}
      {stale && <div className="notice" role="alert"><p>Another reviewer updated this report. Copy any notes you want to keep, then load the latest review.</p><button type="button" className="button button-secondary" onClick={() => reset(report)}>Discard edits and load latest</button></div>}
      <div className="report-transition-confirm"><button className="button button-primary" disabled={busy || stale}>{busy ? 'Saving…' : actions[action].button}</button></div>
    </form>}
    {error && <p className="notice error" role="alert">{error}</p>}
  </section>;
}
