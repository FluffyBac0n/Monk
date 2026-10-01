#!/usr/bin/env node
// Read-only independent count check against the same live historical snapshot.
import path from 'node:path';
import { parseArgs } from 'node:util';
import { verifyBackup, databaseName, authenticatedRequest } from './firestore-backup-lib.mjs';

async function main() {
  const { values } = parseArgs({ options: { backup: { type: 'string' } } });
  if (!values.backup) throw new Error('Usage: node scripts/firestore-backup-live-verify.mjs --backup DIR');
  const { manifest, documents, sourceRoot } = await verifyBackup(path.resolve(values.backup));
  const request = await authenticatedRequest(manifest.projectId);
  const root = `https://firestore.googleapis.com/v1/${databaseName(manifest.projectId, manifest.databaseId)}/documents`;
  const byCollection = new Map();
  for (const document of documents) {
    const relative = document.name.slice(sourceRoot.length + 1);
    const collection = relative.slice(0, relative.lastIndexOf('/'));
    byCollection.set(collection, (byCollection.get(collection) || 0) + 1);
  }
  let checked = 0;
  let total = 0;
  for (const collection of manifest.collections) {
    const parts = collection.split('/').map(decodeURIComponent);
    const id = parts.pop();
    const parent = parts.length ? `${root}/${parts.map(encodeURIComponent).join('/')}` : root;
    const response = await request(`${parent}:runAggregationQuery`, {
      method: 'POST', body: JSON.stringify({
        readTime: manifest.readTime,
        structuredAggregationQuery: { structuredQuery: { from: [{ collectionId: id }] }, aggregations: [{ count: {}, alias: 'count' }] },
      }),
    });
    const value = response.find(item => item.result)?.result.aggregateFields.count.integerValue;
    if (value === undefined) throw new Error('Live count response missing.');
    const count = Number(value);
    if (count !== (byCollection.get(parts.concat(id).join('/')) || 0)) throw new Error('Live collection count does not match the snapshot.');
    checked++;
    total += count;
  }
  if (total !== documents.length) throw new Error('Live total count differs from backup.');
  console.log(JSON.stringify({ liveCountsVerified: true, collectionsChecked: checked, documents: total, readTime: manifest.readTime }));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
