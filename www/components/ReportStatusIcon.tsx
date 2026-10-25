import {reportStatuses} from '@/lib/trail-reports';
export function ReportStatusIcon({status}:{status:string}) {
  return <svg className={`report-status-icon status-${reportStatuses.includes(status)?status:'all'}`} width="22" height="22" viewBox="0 0 48 48" aria-hidden="true"><path d="M21 6a3.5 3.5 0 0 1 6 0l18 31a3.5 3.5 0 0 1-3 5H6a3.5 3.5 0 0 1-3-5Z"/><text x="24" y="34" textAnchor="middle">!</text></svg>;
}
