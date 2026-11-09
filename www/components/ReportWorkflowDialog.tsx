'use client';
import {useEffect, useId, useRef} from 'react';
import {ReportStatusIcon} from './ReportStatusIcon';

export function ReportWorkflowDialog({open, onClose}: {open: boolean; onClose: () => void}) {
  const dialog = useRef<HTMLDialogElement>(null), titleId = useId();
  useEffect(() => {
    if (!open) return;
    const element = dialog.current;
    if (!element) return;
    const previousOverflow = document.body.style.overflow;
    element.showModal(); document.body.style.overflow = 'hidden';
    return () => {element.close(); document.body.style.overflow = previousOverflow;};
  }, [open]);
  return <dialog ref={dialog} className="notify-dialog report-workflow-dialog" aria-labelledby={titleId} onClose={onClose} onClick={event => {if (event.target === event.currentTarget) onClose();}}>
    <div className="notify-dialog-panel">
      <button type="button" className="notify-dialog-close" aria-label="Close workflow" onClick={onClose}>×</button>
      <h2 id={titleId} className="section-title">Incident workflow</h2>
      <ol className="report-workflow-guide">
        {[
          ['new', 'Received', 'Check the location, description and photos.'],
          ['reviewed', 'Reviewed', 'Confirm the issue and decide what needs to happen next.'],
          ['forwarded', 'Sent · when needed', 'Send the report to the responsible authority, then record the recipient and follow up.'],
          ['resolved', 'Resolved', 'Record the work completed or how the repair was confirmed.'],
        ].map(([status, label, description]) => <li key={status}><ReportStatusIcon status={status}/><div><strong>{label}</strong><p>{description}</p></div></li>)}
      </ol>
      <p className="report-helper">An active incident can also be resolved directly, dismissed with a reason, or linked to a duplicate. Closed incidents can be reopened for review.</p>
      <p className="report-helper">Only Reviewed and Sent incidents approved for public display appear on the mobile trail map.</p>
    </div>
  </dialog>;
}
