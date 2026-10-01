import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import { FORMAT, databaseName, captureDocuments, indexSpec, rewriteReferences, restoreWrite, verifyBackup, restoreDocuments } from '../scripts/firestore-backup-lib.mjs';

const source = 'projects/source-project/databases/(default)/documents';
const target = 'projects/target-project/databases/(default)/documents';
const root = `https://firestore.googleapis.com/v1/${source}`;
const readTime = '2026-10-01T10:00:00.123456Z';
const document = name => ({ name: `${source}/${name}`, fields: {}, createTime: readTime, updateTime: readTime });

test('explicit project/database validation prevents path injection', () => {
  assert.equal(databaseName('target-project'), 'projects/target-project/databases/(default)');
  assert.throws(() => databaseName('../target-project'));
  assert.throws(() => databaseName('target-project', '../other'));
});

test('snapshot crawl handles pagination, subcollections and missing parents', async () => {
  const seen = [];
  const calls = [];
  const request = async (url, options) => {
    calls.push(url);
    if (url.endsWith(':listCollectionIds')) {
      const body = JSON.parse(options.body);
      assert.equal(body.readTime, readTime);
      if (url === `${root}:listCollectionIds`) {
        return body.pageToken ? { collectionIds: ['admins'] } : { collectionIds: ['trails'], nextPageToken: 'next' };
      }
      return { collectionIds: decodeURIComponent(url).includes('/trails/missing:') ? ['stages'] : [] };
    }
    const parsed = new URL(url);
    assert.equal(parsed.searchParams.get('readTime'), readTime);
    assert.equal(parsed.searchParams.get('showMissing'), 'true');
    const pathname = decodeURIComponent(parsed.pathname);
    if (pathname.endsWith('/trails')) {
      return parsed.searchParams.get('pageToken')
        ? { documents: [{ name: `${source}/trails/missing` }] }
        : { documents: [document('trails/cyprus-e4')], nextPageToken: 'next-doc' };
    }
    if (pathname.endsWith('/stages')) return { documents: [document('trails/missing/stages/stage1')] };
    if (pathname.endsWith('/admins')) return { documents: [document('admins/user1')] };
    throw new Error('Unexpected request');
  };
  const result = await captureDocuments(request, root, readTime, item => seen.push(item));
  assert.equal(seen.length, 3);
  assert.deepEqual(result.counts, { trails: 2, admins: 1 });
  assert.deepEqual(result.missingParents, ['trails/missing']);
  assert.ok(calls.some(url => url.includes('pageToken=next-doc')));
});

test('index export retains composite fields, exemptions, group scope and TTL', () => {
  const spec = indexSpec([{
    name: 'projects/source-project/databases/(default)/collectionGroups/lodgings/indexes/index1',
    queryScope: 'COLLECTION_GROUP', fields: [{ fieldPath: 'type', order: 'ASCENDING' }, { fieldPath: 'price', order: 'DESCENDING' }, { fieldPath: '__name__', order: 'DESCENDING' }],
  }], [{
    name: 'projects/source-project/databases/(default)/collectionGroups/drafts/fields/expiresAt',
    ttlConfig: { state: 'ACTIVE' }, indexConfig: { indexes: [] },
  }, {
    name: 'projects/source-project/databases/(default)/collectionGroups/lodgings/fields/name',
    indexConfig: { indexes: [{ queryScope: 'COLLECTION_GROUP', fields: [{ fieldPath: 'name', order: 'ASCENDING' }, { fieldPath: '__name__', order: 'ASCENDING' }] }] },
  }]);
  assert.equal(spec.indexes[0].fields.length, 2);
  assert.equal(spec.fieldOverrides[0].ttl, true);
  assert.deepEqual(spec.fieldOverrides[0].indexes, []);
  assert.equal(spec.fieldOverrides[1].indexes[0].queryScope, 'COLLECTION_GROUP');
});

test('restore preserves typed fields, only rewrites actual same-database references', () => {
  const fields = {
    integer: { integerValue: '9223372036854775807' }, timestamp: { timestampValue: readTime }, bytes: { bytesValue: 'AAEC' },
    geo: { geoPointValue: { latitude: 35, longitude: 33 } }, text: { stringValue: `${source}/trails/cyprus-e4` },
    map: { mapValue: { fields: { links: { arrayValue: { values: [{ referenceValue: `${source}/trails/cyprus-e4` }, { referenceValue: 'projects/external-project/databases/(default)/documents/other/id' }] } } } } },
  };
  const copy = rewriteReferences(fields, source, target);
  assert.deepEqual(copy.integer, fields.integer);
  assert.deepEqual(copy.text, fields.text);
  assert.equal(copy.map.mapValue.fields.links.arrayValue.values[0].referenceValue, `${target}/trails/cyprus-e4`);
  assert.equal(fields.map.mapValue.fields.links.arrayValue.values[0].referenceValue, `${source}/trails/cyprus-e4`);
  const write = restoreWrite({ ...document('trails/cyprus-e4'), fields }, source, target);
  assert.deepEqual(write.currentDocument, { exists: false });
  assert.equal(write.update.name, `${target}/trails/cyprus-e4`);
  assert.equal(write.update.createTime, undefined);
});

test('local backup integrity rejects corruption, incomplete backups and duplicate documents', async t => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'eurotrex-backup-test-'));
  t.after(() => fs.rm(directory, { recursive: true }));
  const docs = `${JSON.stringify(document('trails/cyprus-e4'))}\n`;
  const config = '{}\n';
  const sha = content => crypto.createHash('sha256').update(content).digest('hex');
  const manifest = { format: FORMAT, complete: true, projectId: 'source-project', databaseId: '(default)', documentCount: 1, counts: { trails: 1 }, sha256: { 'documents.jsonl': sha(docs), 'configuration.json': sha(config) } };
  await fs.writeFile(path.join(directory, 'documents.jsonl'), docs);
  await fs.writeFile(path.join(directory, 'configuration.json'), config);
  await fs.writeFile(path.join(directory, 'manifest.json'), JSON.stringify(manifest));
  assert.equal((await verifyBackup(directory)).documents.length, 1);
  await fs.appendFile(path.join(directory, 'documents.jsonl'), docs);
  await assert.rejects(verifyBackup(directory), /Checksum/);
  manifest.sha256['documents.jsonl'] = sha(docs + docs);
  await fs.writeFile(path.join(directory, 'manifest.json'), JSON.stringify(manifest));
  await assert.rejects(verifyBackup(directory), /Duplicate/);
  manifest.complete = false;
  await fs.writeFile(path.join(directory, 'manifest.json'), JSON.stringify(manifest));
  await assert.rejects(verifyBackup(directory), /completed/);
});

test('restore writes only trails by default and rejects populated targets before any writes', async () => {
  const backup = { sourceRoot: source, documents: [document('trails/cyprus-e4'), document('admins/user1'), document('ownerProfiles/user2')] };
  const commits = [];
  const request = async (url, options) => {
    if (url.endsWith(':listCollectionIds')) return { collectionIds: [] };
    commits.push(JSON.parse(options.body));
    return {};
  };
  assert.equal(await restoreDocuments(request, 'https://firestore.googleapis.com/v1', backup, { project: 'target-project' }), 1);
  assert.equal(commits[0].writes[0].update.name, `${target}/trails/cyprus-e4`);
  commits.length = 0;
  assert.equal(await restoreDocuments(request, 'https://firestore.googleapis.com/v1', backup, { project: 'target-project', scope: 'all' }), 2);
  assert.ok(!commits[0].writes.some(write => write.update.name.includes('/admins/')));
  commits.length = 0;
  assert.equal(await restoreDocuments(request, 'https://firestore.googleapis.com/v1', backup, { project: 'target-project', scope: 'all', includeAdmins: true }), 3);
  await assert.rejects(restoreDocuments(async () => ({ collectionIds: ['trails'] }), 'https://firestore.googleapis.com/v1', backup, { project: 'target-project' }), /empty destination/);
});

test('large restores are batched and every write is create-only', async () => {
  const commits = [];
  const request = async (url, options) => {
    if (url.endsWith(':listCollectionIds')) return {};
    const body = JSON.parse(options.body);
    commits.push(body);
    assert.ok(body.writes.every(write => write.currentDocument.exists === false));
    return {};
  };
  const backup = { sourceRoot: source, documents: Array.from({ length: 205 }, (_, i) => document(`trails/trail${i}`)) };
  assert.equal(await restoreDocuments(request, 'https://firestore.googleapis.com/v1', backup, { project: 'target-project' }), 205);
  assert.deepEqual(commits.map(batch => batch.writes.length), [100, 100, 5]);
});
