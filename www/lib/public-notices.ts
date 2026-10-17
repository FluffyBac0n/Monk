import type { PublicIssue } from './public-trail-data';

const escape = (value: string) =>
  value.replace(
    /[&<>"']/g,
    (char) =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[
        char
      ]!
  );
export function publicNoticeHtml(
  issues: PublicIssue[],
  available: boolean
): string {
  if (!available)
    return '<p class="trail-data-message" role="status">Trail notices could not be refreshed. Please try again shortly and check current local advice.</p>';
  if (!issues.length)
    return '<p class="trail-data-message">No active approved notices are currently published for this trail. This does not confirm that the route is clear; check weather, local advice and official access information.</p>';
  const cards = issues
    .map((issue) => {
      const updated = Number.isFinite(Date.parse(issue.updatedAt))
        ? new Intl.DateTimeFormat('en-GB', {
            dateStyle: 'medium',
            timeZone: 'UTC',
          }).format(new Date(issue.updatedAt))
        : 'Not recorded';
      return `<article class="trail-notice"><p class="eyebrow">${escape(issue.category.replaceAll('_', ' ') || 'Trail notice')}</p><h3>${escape(issue.passability.replaceAll('_', ' ') || 'Check conditions')}</h3><p>${escape(issue.description)}</p><small>Updated ${escape(updated)}</small></article>`;
    })
    .join('');
  return `<div class="notice-grid">${cards}</div>`;
}
