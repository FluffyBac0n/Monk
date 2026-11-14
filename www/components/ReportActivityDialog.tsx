'use client';
import {useEffect, useId, useRef} from 'react';
import type {ReportEvent} from '@/lib/trail-reports';
import {reportStatusLabels} from './ReportReview';

export function ReportActivityDialog({open, onClose, reference, events, loading, error}: {
  open: boolean; onClose: () => void; reference: string; events: ReportEvent[]; loading: boolean; error: string;
}) {
  const dialog = useRef<HTMLDialogElement>(null), titleId = useId();
  useEffect(() => {
    if (!open || !dialog.current) return;
    const element = dialog.current, previousFocus = document.activeElement as HTMLElement | null;
    const previousOverflow = document.body.style.overflow;
    element.showModal(); document.body.style.overflow = 'hidden';
    return () => {element.close(); document.body.style.overflow = previousOverflow; previousFocus?.focus();};
  }, [open]);
  return <dialog ref={dialog} className="notify-dialog report-activity-dialog" aria-labelledby={titleId}
    onCancel={event => {event.preventDefault(); onClose();}} onClose={onClose}
    onClick={event => {if (event.target === event.currentTarget) onClose();}}>
    <div className="notify-dialog-panel">
      <button type="button" className="notify-dialog-close" aria-label="Close activity log" onClick={onClose}>×</button>
      <h2 id={titleId} className="section-title">Activity log</h2>
      <p className="report-activity-reference">{reference}</p>
      {error ? <p className="notice error" role="alert">{error}</p> : loading ? <p role="status">Loading activity…</p> : !events.length ? <p className="report-helper">No activity recorded yet.</p> :
        <ol className="report-history">{events.map(event => <li key={event.id}>
          <strong>{event.previousStatus && event.status && event.previousStatus !== event.status ? `${reportStatusLabels[event.previousStatus] || event.previousStatus} → ${reportStatusLabels[event.status] || event.status}` : event.action === 'review' ? `Details updated · ${reportStatusLabels[event.status || ''] || event.status}` : 'Report received'}</strong>
          <span>{event.createdAt?.toDate().toLocaleString()} · {event.actorEmail || 'Reporter'}</span>
          {event.note && <p>{event.note}</p>}
          {event.authority && <p>Authority: {event.authority} {event.forwardingReference}</p>}
        </li>)}</ol>}
    </div>
  </dialog>;
}
