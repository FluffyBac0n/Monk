#!/usr/bin/env node
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { parseArgs } from 'node:util';
import {
  ROOT, FORMAT, databaseName, authenticatedRequest, allPages, captureDocuments,
  indexSpec, verifyBackup, restoreDocuments,
} from './firestore-backup-lib.mjs';

const { values, positionals } = parseArgs({ allowPositionals: true, options: {
  project: { type: 'string' }, database: { type: 'string', default: '(default)' },
  out: { type: 'string' }, backup: { type: 'string' }, scope: { type: 'string', default: 'trails' },
  commit: { type: 'boolean', default: false }, 'confirm-project': { type: 'string' },
  'include-admins': { type: 'boolean', default: false },
} });

async function main() {
  const [command] = positionals;
  if (positionals.length !== 1 || !['export', 'verify', 'restore'].includes(command)) {
    throw new Error('Usage: node scripts/firestore-backup.mjs export --project ID [--out DIR] | verify --backup DIR | restore --backup DIR --project NEW_ID [--scope trails|all] [--commit --confirm-project NEW_ID]');
  }
  if (command === 'verify' || command === 'restore') {
    if (!values.backup) throw new Error('--backup is required.');
    const backup = await verifyBackup(path.resolve(values.backup));
    if (command === 'verify') {
      console.log(JSON.stringify({ verified: true, documentCount: backup.manifest.documentCount, counts: backup.manifest.counts }));
      return;
    }
    if (!values.project) throw new Error('--project is required.');
    databaseName(values.project, values.database);
    if (values.project === backup.manifest.projectId) throw new Error('Restore to the source project is forbidden. Use a fresh, separate project.');
    if (!['trails', 'all'].includes(values.scope)) throw new Error('--scope must be trails or all.');
    const plan = { targetProject: values.project, database: values.database, scope: values.scope, includeAdmins: values['include-admins'], sourceDocuments: backup.documents.length };
    if (!values.commit) { console.log(JSON.stringify({ dryRun: true, ...plan })); return; }
    if (values['confirm-project'] !== values.project) throw new Error('--confirm-project must exactly match the new project.');
    const request = await authenticatedRequest(values.project);
    // Prevent commit retries after an ambiguous success. GET/list requests are safe to retry.
    const strictRequest = async (url, options = {}) => {
      if (!url.endsWith(':commit')) return request(url, options);
      const { createRequire } = await import('node:module');
      const require = createRequire(path.join(ROOT, 'package.json'));
      const { getAccessToken } = require('firebase-tools/lib/apiv2.js');
      const response = await fetch(url, { ...options, signal: AbortSignal.timeout(60000), headers: { 'content-type': 'application/json', authorization: `Bearer ${await getAccessToken()}` } });
      if (!response.ok) throw new Error(`Restore commit failed with HTTP ${response.status}. Partial restore may exist; inspect the destination before proceeding.`);
      return response.json();
    };
    const restored = await restoreDocuments(strictRequest, 'https://firestore.googleapis.com/v1', backup, {
      project: values.project, database: values.database, scope: values.scope, includeAdmins: values['include-admins'],
    });
    console.log(JSON.stringify({ restored, ...plan }));
    return;
  }

  if (!values.project) throw new Error('Explicit --project is required; no default project is used.');
  const name = databaseName(values.project, values.database);
  const request = await authenticatedRequest(values.project);
  const api = 'https://firestore.googleapis.com/v1';
  const database = await request(`${api}/${name}`);
  // Match the Firebase CLI's wildcard listing; let the service choose page size.
  const indexes = await allPages(request, `${api}/${name}/collectionGroups/-/indexes`, 'indexes');
  const fields = await allPages(request, `${api}/${name}/collectionGroups/-/fields`, 'fields', {
    filter: 'indexConfig.usesAncestorConfig=false OR ttlConfig:*',
  });
  const backupSchedules = await allPages(request, `${api}/${name}/backupSchedules`, 'backupSchedules');
  const rulesApi = `https://firebaserules.googleapis.com/v1/projects/${values.project}`;
  const releaseName = values.database === '(default)' ? 'cloud.firestore' : `cloud.firestore/${values.database}`;
  const release = await request(`${rulesApi}/releases/${releaseName}`);
  const ruleset = await request(`https://firebaserules.googleapis.com/v1/${release.rulesetName}`);
  const configuration = { database, backupSchedules, indexes: indexSpec(indexes, fields), rawIndexes: indexes, rawFieldOverrides: fields, rulesetName: release.rulesetName, rules: ruleset.source.files };
  const documentsRoot = `${api}/${name}/documents`;
  const probe = await request(`${documentsRoot}:runQuery`, {
    method: 'POST', body: JSON.stringify({ structuredQuery: { from: [{ collectionId: 'trails' }], limit: 1 } }),
  });
  const readTime = probe.find(item => item.readTime)?.readTime;
  if (!readTime) throw new Error('Could not obtain a database snapshot time.');
  const directory = path.resolve(values.out || path.join(ROOT, 'private-backups', `${values.project}-${new Date().toISOString().replace(/[:.]/g, '-')}`));
  const privateRoot = path.join(ROOT, 'private-backups');
  if (!directory.startsWith(`${privateRoot}${path.sep}`)) throw new Error('Backups must be under the Git-ignored private-backups/ directory.');
  await fs.mkdir(privateRoot, { recursive: true, mode: 0o700 });
  await fs.mkdir(directory, { mode: 0o700 }); // Refuse to overwrite an existing backup.
  const handle = await fs.open(path.join(directory, 'documents.jsonl'), 'wx', 0o600);
  let count = 0;
  let result;
  const startedAt = new Date().toISOString();
  try {
    result = await captureDocuments(request, documentsRoot, readTime, async document => {
      await handle.writeFile(`${JSON.stringify(document)}\n`);
      count++;
    }, () => { if (count % 250 === 0) console.log(`Downloaded ${count} documents (no document contents logged).`); });
    await handle.sync();
  } finally { await handle.close(); }
  await fs.writeFile(path.join(directory, 'configuration.json'), `${JSON.stringify(configuration, null, 2)}\n`, { mode: 0o600, flag: 'wx' });
  const sha256 = {};
  for (const file of ['documents.jsonl', 'configuration.json']) {
    sha256[file] = crypto.createHash('sha256').update(await fs.readFile(path.join(directory, file))).digest('hex');
  }
  const manifest = {
    format: FORMAT, complete: true, projectId: values.project, databaseId: values.database,
    startedAt, completedAt: new Date().toISOString(), readTime, documentCount: count,
    ...result, sha256,
    exclusions: ['Firebase Authentication users/passwords', 'Storage objects', 'IAM', 'App Check', 'API keys', 'PITR history', 'managed scheduled backups'],
  };
  await fs.writeFile(path.join(directory, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600, flag: 'wx' });
  await verifyBackup(directory);
  console.log(JSON.stringify({ complete: true, directory, readTime, documentCount: count, counts: result.counts, location: database.locationId, compositeIndexes: indexes.length, fieldOverrides: configuration.indexes.fieldOverrides.length }));
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
