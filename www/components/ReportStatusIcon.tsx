import {reportStatuses} from '@/lib/trail-reports';
import {reportStatusSymbol} from '@/lib/report-status-symbols';
export function ReportStatusIcon({status}:{status:string}) {
  return <svg className={`report-status-icon status-${reportStatuses.includes(status)?status:'all'}`} width="22" height="22" viewBox="0 0 24 24" aria-hidden="true"><circle className="report-status-disc" cx="12" cy="12" r="11"/><path className="report-status-glyph" d={reportStatusSymbol(status)}/></svg>;
}
