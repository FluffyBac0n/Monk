import type {TrailReport} from './trail-reports';
import {normaliseSearch} from './fuzzy-search';

export function incidentSearchText(report: TrailReport, category: string, status: string) {
  return normaliseSearch([
    report.id, report.ticketReference, category, status, report.description, report.priority, report.passability,
    report.authority, report.forwardingReference, report.stageId,
    report.origin === 'organisation' ? 'Organisation-created' : 'Hiker report',
    report.receivedAt?.toDate().toLocaleDateString(), new Date(report.observedAtMs).toLocaleDateString(),
  ].filter(Boolean).join(' '));
}
