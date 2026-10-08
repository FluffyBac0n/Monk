export const categories = ['signpost', 'vegetation', 'obstruction', 'path_damage', 'other'];
export const passabilities = ['passable', 'difficult', 'blocked', 'unsure'];
export const statuses = ['new', 'reviewed', 'forwarded', 'resolved', 'duplicate', 'dismissed'];
export const idPattern = /^[a-zA-Z0-9_-]{1,100}$/;
export function requireId(value) {
  if (typeof value !== 'string' || !idPattern.test(value)) throw new Error('Invalid identifier.');
  return value;
}
export function text(value, max, required = false) {
  if (typeof value !== 'string' || value.trim().length > max || (required && !value.trim())) throw new Error('Invalid text field.');
  return value.trim();
}
export function validateReport(data) {
  if (!data || typeof data !== 'object') throw new Error('Report is required.');
  const trailId = requireId(data.trailId);
  const description = text(data.description, 500, true);
  if (!categories.includes(data.category) || !passabilities.includes(data.passability)) throw new Error('Choose a problem type and trail access.');
  if (!['gps', 'pin'].includes(data.locationSource)) throw new Error('Confirm the problem location.');
  const {latitude, longitude} = data;
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) throw new Error('Invalid coordinates.');
  const accuracyM = data.locationSource === 'gps' ? data.accuracyM : null;
  if (accuracyM != null && (!Number.isFinite(accuracyM) || accuracyM < 0 || accuracyM > 100000)) throw new Error('Invalid GPS accuracy.');
  if (!Array.isArray(data.photoIds) || data.photoIds.length > 3 || new Set(data.photoIds).size !== data.photoIds.length) throw new Error('Choose up to three photos.');
  data.photoIds.forEach(requireId);
  const contactEmail = text(data.contactEmail || '', 254);
  if (contactEmail && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(contactEmail)) throw new Error('Invalid contact email.');
  const observedAtMs = data.observedAtMs;
  if (!Number.isFinite(observedAtMs) || observedAtMs < 0 || observedAtMs > Date.now() + 86400000) throw new Error('Invalid observation date.');
  return {trailId, description, category: data.category, passability: data.passability,
    latitude, longitude, locationSource: data.locationSource, accuracyM: accuracyM ?? null,
    observedAtMs, photoIds: data.photoIds, contactEmail, appVersion: text(data.appVersion || '', 80),
    // Context is a suggestion from the selected stage, never an authorization input.
    stageId: data.stageId ? requireId(data.stageId) : null};
}
export function mayReview({verified, admin, trailIds}, trailId) {
  return verified === true && (admin === true || (Array.isArray(trailIds) && trailIds.includes(trailId)));
}
export function validateReview(data, reportId) {
  if (!statuses.includes(data.status)) throw new Error('Invalid report status.');
  if (!['normal', 'high', 'urgent'].includes(data.priority)) throw new Error('Invalid priority.');
  const authority = text(data.authority || '', 200);
  const forwardingReference = text(data.forwardingReference || '', 300);
  const note = text(data.note || '', 1500);
  const duplicateOf = data.status === 'duplicate' ? requireId(data.duplicateOf) : null;
  if (duplicateOf === reportId) throw new Error('A report cannot duplicate itself.');
  if (data.status === 'forwarded' && !authority) throw new Error('Enter the authority before marking as forwarded.');
  if (['resolved', 'dismissed'].includes(data.status) && !note) throw new Error('Add a resolution or dismissal note.');
  return {status: data.status, priority: data.priority, authority, forwardingReference, note, duplicateOf};
}
