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

// Older app builds omit this manifest. New builds must describe every original
// photo so a retry cannot silently reuse a truncated or different upload.
export function validatePhotoChecksums(value, photoIds) {
  if (value === undefined) return null;
  if (!Array.isArray(value) || value.length !== photoIds.length || value.length > 3) throw new Error('Invalid photo checksums.');
  const checksums = new Map();
  for (const item of value) {
    if (!item || typeof item !== 'object') throw new Error('Invalid photo checksum.');
    const id = requireId(item.id);
    if (!photoIds.includes(id) || checksums.has(id)) throw new Error('Invalid photo identifier.');
    if (typeof item.md5Hash !== 'string' || !/^[A-Za-z0-9+/]{22}==$/.test(item.md5Hash)
      || Buffer.from(item.md5Hash, 'base64').toString('base64') !== item.md5Hash) throw new Error('Invalid photo checksum.');
    if (!Number.isSafeInteger(item.byteLength) || item.byteLength <= 0 || item.byteLength >= 2 * 1024 * 1024) throw new Error('Invalid photo size.');
    checksums.set(id, {md5Hash: item.md5Hash, byteLength: item.byteLength});
  }
  return checksums;
}
