import {HttpsError} from 'firebase-functions/v2/https';
import {requireId} from './report-model.js';

export function incidentPrefix(trailId, trail) {
  const countries = {cyprus:'CY', greece:'GR', bulgaria:'BG', romania:'RO', serbia:'RS', hungary:'HU', austria:'AT', germany:'DE', switzerland:'CH', france:'FR', spain:'ES', portugal:'PT'};
  const country = String(trail.verificationAuthority?.country || trail.country || '').trim().toLowerCase();
  const code = countries[country] || (/^[A-Z]{2}$/.test(trail.countryCode || '') ? trail.countryCode : undefined)
    || (trailId === 'cyprus-e4' ? 'CY' : ['crete-e4', 'peloponnese-e4'].includes(trailId) ? 'GR' : undefined);
  if (!code) throw new HttpsError('failed-precondition', 'Set the trail country before assigning ticket numbers.');
  return `${trailId.match(/(?:^|-)(e\d+)(?:-|$)/i)?.[1].toUpperCase() || 'E4'}-${code}`;
}

export function createIncidentReferences({db, permission}) {
  return async ({auth, data}) => {
    let trailId, ids;
    try {
      trailId = requireId(data.trailId);
      if (!Array.isArray(data.reportIds) || !data.reportIds.length || data.reportIds.length > 50) throw new Error();
      ids = [...new Set(data.reportIds.map(requireId))];
    } catch {throw new HttpsError('invalid-argument', 'Choose up to 50 incidents.');}
    return db.runTransaction(async tx => {
      await permission(tx, auth, trailId, ['incident_manager']);
      const trail = await tx.get(db.doc(`trails/${trailId}`));
      if (!trail.exists) throw new HttpsError('not-found', 'Trail unavailable.');
      const prefix = incidentPrefix(trailId, trail.data());
      const counterRef = db.doc(`trailReportReferenceCounters/${prefix}`);
      const [counter, ...reports] = await tx.getAll(counterRef, ...ids.map(id => db.doc(`trailReports/${id}`)));
      if (reports.some(report => !report.exists || report.data().trailId !== trailId || report.data().uploadState !== 'complete')) {
        throw new HttpsError('permission-denied', 'Choose received incidents for this trail.');
      }
      let next = counter.data()?.lastNumber || 0;
      const references = {};
      reports.sort((a, b) => (a.data().receivedAt?.toMillis() || 0) - (b.data().receivedAt?.toMillis() || 0) || a.id.localeCompare(b.id));
      for (const report of reports) {
        let reference = report.data().ticketReference;
        if (!reference) {
          next += 1;
          reference = `${prefix}-${String(next).padStart(5, '0')}`;
          // Add metadata only. Keep document IDs, review versions, photos and activity intact.
          tx.update(report.ref, {ticketReference: reference, ticketNumber: next});
        }
        references[report.id] = reference;
      }
      if (next !== (counter.data()?.lastNumber || 0)) tx.set(counterRef, {lastNumber: next});
      return {references};
    });
  };
}
