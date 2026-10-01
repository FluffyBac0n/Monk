import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

export const FORMAT = 'eurotrex-firestore-rest-v1';
export const ROOT = path.resolve(import.meta.dirname, '..');

export function databaseName(project, database = '(default)') {
  if (!/^[a-z][a-z0-9-]{4,62}$/.test(project)) throw new Error('Invalid project ID.');
  if (!/^(\(default\)|[a-z][a-z0-9-]{2,62})$/.test(database)) throw new Error('Invalid database ID.');
  return `projects/${project}/databases/${database}`;
}

export async function authenticatedRequest(project) {
  // Reuse the Firebase CLI login; never write credentials into a backup.
  const require = createRequire(path.join(ROOT, 'package.json'));
  const auth = require('firebase-tools/lib/auth.js');
  const { requireAuth } = require('firebase-tools/lib/requireAuth.js');
  const { getAccessToken } = require('firebase-tools/lib/apiv2.js');
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw new Error('Run the root Firebase CLI login first (without the emulator npm wrapper).');
  await requireAuth({ project, user: account.user, tokens: account.tokens });
  return async (url, options = {}) => {
    for (let attempt = 0; attempt < 5; attempt++) {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(60000),
        headers: { 'content-type': 'application/json', authorization: `Bearer ${await getAccessToken()}` },
      });
      if (response.ok) return response.json();
      if ([429, 500, 502, 503, 504].includes(response.status) && attempt < 4) {
        await new Promise(resolve => setTimeout(resolve, 500 * 2 ** attempt));
        continue;
      }
      // Do not emit response bodies: they can contain private document contents.
      throw new Error(`Firestore request failed with HTTP ${response.status} at ${new URL(url).pathname}.`);
    }
  };
}

export async function allPages(request, url, key, params = {}) {
  const result = [];
  let pageToken;
  do {
    const parsed = new URL(url);
    for (const [name, value] of Object.entries({ ...params, ...(pageToken ? { pageToken } : {}) })) {
      parsed.searchParams.set(name, value);
    }
    const page = await request(parsed.href);
    result.push(...(page[key] || []));
    pageToken = page.nextPageToken;
  } while (pageToken);
  return result;
}

export async function collectionIds(request, root, readTime) {
  const result = [];
  let pageToken;
  do {
    const page = await request(`${root}:listCollectionIds`, {
      method: 'POST',
      body: JSON.stringify({ pageSize: 1000, ...(readTime ? { readTime } : {}), ...(pageToken ? { pageToken } : {}) }),
    });
    result.push(...(page.collectionIds || []));
    pageToken = page.nextPageToken;
  } while (pageToken);
  return result.sort();
}

export async function captureDocuments(request, documentsRoot, readTime, onDocument, onProgress = () => {}) {
  const counts = {};
  const missingParents = [];
  const collections = [];
  async function visit(parent) {
    for (const id of await collectionIds(request, parent, readTime)) {
      const url = `${parent}/${encodeURIComponent(id)}`;
      collections.push(url.slice(documentsRoot.length + 1));
      const documents = await allPages(request, url, 'documents', { pageSize: 1000, showMissing: true, readTime });
      for (const document of documents) {
        const prefix = documentsRoot.replace('https://firestore.googleapis.com/v1/', '');
        if (!document.name?.startsWith(`${prefix}/`)) throw new Error('Unexpected document resource name.');
        const relative = document.name.slice(prefix.length + 1);
        if (document.createTime || document.updateTime) {
          await onDocument(document);
          const top = relative.split('/')[0];
          counts[top] = (counts[top] || 0) + 1;
          onProgress(counts);
        } else {
          missingParents.push(relative);
        }
        // Missing parent documents can still contain live subcollections.
        await visit(`https://firestore.googleapis.com/v1/${document.name.split('/').map(encodeURIComponent).join('/')}`);
      }
    }
  }
  await visit(documentsRoot);
  return { counts, missingParents, collections };
}

export function indexSpec(indexes, fields) {
  const spec = {
    indexes: indexes.map(index => ({
      collectionGroup: decodeURIComponent(index.name.split('/collectionGroups/')[1].split('/')[0]),
      queryScope: index.queryScope,
      fields: index.fields.filter(field => field.fieldPath !== '__name__'),
    })),
    fieldOverrides: fields.filter(field => !field.name.includes('/__default__/')).map(field => ({
      collectionGroup: decodeURIComponent(field.name.split('/collectionGroups/')[1].split('/')[0]),
      fieldPath: decodeURIComponent(field.name.split('/fields/')[1]),
      ...(field.ttlConfig ? { ttl: field.ttlConfig.state !== 'DISABLED' } : {}),
      indexes: (field.indexConfig?.indexes || []).map(index => {
        const value = index.fields.find(item => item.fieldPath !== '__name__');
        if (!value) throw new Error('Unsupported field index configuration.');
        return { queryScope: index.queryScope, ...(value.order ? { order: value.order } : { arrayConfig: value.arrayConfig }) };
      }),
    })),
  };
  spec.indexes.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  spec.fieldOverrides.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  return spec;
}

export function rewriteReferences(value, sourceRoot, targetRoot) {
  if (!value || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(item => rewriteReferences(item, sourceRoot, targetRoot));
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key,
    key === 'referenceValue' && typeof item === 'string' && item.startsWith(`${sourceRoot}/`)
      ? targetRoot + item.slice(sourceRoot.length)
      : rewriteReferences(item, sourceRoot, targetRoot),
  ]));
}

export function restoreWrite(document, sourceRoot, targetRoot) {
  return {
    update: {
      name: targetRoot + document.name.slice(sourceRoot.length),
      fields: rewriteReferences(document.fields || {}, sourceRoot, targetRoot),
    },
    currentDocument: { exists: false },
  };
}

export async function verifyBackup(directory) {
  const manifest = JSON.parse(await fs.readFile(path.join(directory, 'manifest.json'), 'utf8'));
  if (manifest.format !== FORMAT || manifest.complete !== true) throw new Error('Not a completed, supported backup.');
  for (const [file, expected] of Object.entries(manifest.sha256)) {
    if (!['documents.jsonl', 'configuration.json'].includes(file)) throw new Error('Invalid manifest filename.');
    const actual = crypto.createHash('sha256').update(await fs.readFile(path.join(directory, file))).digest('hex');
    if (actual !== expected) throw new Error(`Checksum mismatch: ${file}`);
  }
  if (!manifest.sha256['documents.jsonl'] || !manifest.sha256['configuration.json']) throw new Error('Missing backup checksums.');
  const sourceRoot = `${databaseName(manifest.projectId, manifest.databaseId)}/documents`;
  const documents = (await fs.readFile(path.join(directory, 'documents.jsonl'), 'utf8')).split('\n').filter(Boolean).map(line => JSON.parse(line));
  const seen = new Set();
  const counts = {};
  for (const document of documents) {
    if (!document.name?.startsWith(`${sourceRoot}/`)) throw new Error('Document is outside the source database.');
    const relative = document.name.slice(sourceRoot.length + 1);
    const segments = relative.split('/');
    if (segments.length % 2 || segments.some(segment => !segment || segment === '.' || segment === '..')) throw new Error('Invalid document path.');
    if (seen.has(document.name)) throw new Error('Duplicate document in backup.');
    seen.add(document.name);
    counts[segments[0]] = (counts[segments[0]] || 0) + 1;
  }
  if (documents.length !== manifest.documentCount) throw new Error('Document count mismatch.');
  if (JSON.stringify(Object.entries(counts).sort()) !== JSON.stringify(Object.entries(manifest.counts).sort())) throw new Error('Collection counts mismatch.');
  return { manifest, documents, sourceRoot };
}

export async function restoreDocuments(request, base, backup, { project, database = '(default)', scope = 'trails', includeAdmins = false }) {
  if (!['trails', 'all'].includes(scope)) throw new Error('Scope must be trails or all.');
  const targetRoot = `${databaseName(project, database)}/documents`;
  const targetUrl = `${base}/${targetRoot}`;
  if ((await collectionIds(request, targetUrl)).length) throw new Error('Restore requires an empty destination database.');
  const selected = backup.documents.filter(document => {
    const top = document.name.slice(backup.sourceRoot.length + 1).split('/')[0];
    return scope === 'trails' ? top === 'trails' : includeAdmins || top !== 'admins';
  });
  // Small batches also bound payload size when route chunks contain many points.
  let writes = [];
  let bytes = 0;
  let restored = 0;
  async function flush() {
    if (!writes.length) return;
    // No automatic retry of commits: ambiguous network failures require inspection.
    await request(`${targetUrl}:commit`, { method: 'POST', body: JSON.stringify({ writes }) });
    restored += writes.length;
    writes = [];
    bytes = 0;
  }
  for (const document of selected) {
    const write = restoreWrite(document, backup.sourceRoot, targetRoot);
    const size = Buffer.byteLength(JSON.stringify(write));
    if (writes.length >= 100 || bytes + size > 4 * 1024 * 1024) await flush();
    writes.push(write);
    bytes += size;
  }
  await flush();
  return restored;
}
