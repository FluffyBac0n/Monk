import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const files = Object.fromEntries(['trail-route', 'route-geometry'].map(name => [name, ts.transpileModule(readFileSync(new URL(`../lib/${name}.ts`, import.meta.url), 'utf8'), {compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022}}).outputText]));
const cache = new Map();
let reads = 0, chunkReads = 0, revision = 1, failNext = false;
const later = callback => queueMicrotask(callback);
const indexedDB = {open() {
  const request = {};
  later(() => {
    request.result = {close() {}, transaction() {
      const transaction = {objectStore() {
        const requestFor = result => {const request = {result}; later(() => {request.onsuccess?.(); transaction.oncomplete?.();}); return request;};
        return {get: key => requestFor(cache.get(key)), put: (value, key) => {cache.set(key, value); return requestFor(key);}};
      }};
      return transaction;
    }};
    request.onsuccess?.();
  });
  return request;
}};
const firestore = {
  doc: (...args) => args, collection: (...args) => args, orderBy: value => value, query: (...args) => args,
  async getDoc() {reads++; if (failNext) {failNext = false; throw new Error('Temporary failure');} return {exists: () => true, data: () => ({version: revision, updatedAt: {toMillis: () => revision}, pointFormat: ['lat','lng'], pointStride: 2, pointCount: 2, chunkCount: 1})};},
  async getDocs() {chunkReads++; return {size: 1, docs: [{data: () => ({points: [34, 32, 35, 33]})}]};},
};
function loadModule(name, diskCache = indexedDB) {
  const exports = {};
  vm.runInNewContext(files[name], {exports, setTimeout, clearTimeout, indexedDB: diskCache, require(id) {
    if (id === 'firebase/firestore') return firestore;
    if (id === './firebase') return {db: {app: {options: {projectId: 'test-project'}}}};
    if (id === './route-geometry') return loadModule('route-geometry');
    throw new Error(`Unexpected dependency: ${id}`);
  }});
  return exports;
}
let loader = loadModule('trail-route');
const [one, two] = await Promise.all([loader.loadTrailRoute('trail'), loader.loadTrailRoute('trail')]);
assert.equal(one, two); assert.equal(reads, 1); assert.equal(chunkReads, 1);
await new Promise(resolve => setImmediate(resolve));
loader = loadModule('trail-route');
await loader.loadTrailRoute('trail'); assert.equal(reads, 2); assert.equal(chunkReads, 1, 'A page reload reuses unchanged public geometry');
revision++;
await loadModule('trail-route').loadTrailRoute('trail'); assert.equal(chunkReads, 2, 'A changed route version downloads fresh geometry');
loader = loadModule('trail-route'); failNext = true;
await assert.rejects(loader.loadTrailRoute('retry'), /Temporary/);
await loader.loadTrailRoute('retry'); assert.equal(chunkReads, 3, 'Failed preloads can be retried');
await loadModule('trail-route', null).loadTrailRoute('uncached');
assert.equal(chunkReads, 4);
assert.deepEqual(Object.keys(cache.get('test-project:trail')).sort(), ['coordinates', 'revision']);
console.log('Passed: concurrent preload deduplication, reload cache reuse, version invalidation, failed-load retry, cache fallback and public-geometry-only storage.');
