// Shared by React controls and Mapbox's DOM markers.
const symbols: Record<string, string> = {
  new: 'M12 6.5v7M12 17v.5',
  reviewed: 'M3.5 12s3-5 8.5-5 8.5 5 8.5 5-3 5-8.5 5-8.5-5-8.5-5ZM14.5 12a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0',
  forwarded: 'M5 12h14M13 6l6 6-6 6',
  resolved: 'm6 12 4 4 8-8',
  duplicate: 'M9 9h9v9H9ZM6 15H5V5h10v1',
  dismissed: 'm7 7 10 10M17 7 7 17',
  all: 'M6 6h4v4H6ZM14 6h4v4h-4ZM6 14h4v4H6ZM14 14h4v4h-4Z',
};
export function reportStatusSymbol(status: string) {return symbols[status] || symbols.all;}
export function reportStatusMarker(status: string) {
  return `<svg viewBox="0 0 24 24" aria-hidden="true"><circle class="report-status-disc" cx="12" cy="12" r="11"/><path class="report-status-glyph" d="${reportStatusSymbol(status)}"/></svg>`;
}
