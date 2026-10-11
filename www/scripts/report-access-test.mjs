import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../lib/report-access.ts', import.meta.url), 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022},
}).outputText;
const tick = () => new Promise(resolve => setImmediate(resolve));
function session({slowCatalog = false} = {}) {
  const listeners = new Map(), timers = new Map(), states = [], requests = [];
  let clockId = 0, reads = 0, tokenArgs;
  const catalog = {docs: ['cyprus', 'crete'].map(id => ({id, data: () => ({name: id})}))};
  const firestore = {
    collection: (_db, name) => name, doc: (_db, name, id) => `${name}/${id}`,
    getDocsFromServer: () => {reads++; return slowCatalog ? new Promise((resolve, reject) => requests.push({resolve, reject})) : Promise.resolve(catalog);},
    onSnapshot: (path, _options, receive, fail) => {listeners.set(path, {receive, fail}); return () => listeners.delete(path);},
  };
  const exports = {};
  vm.runInNewContext(code, {exports, require: path => path === 'firebase/firestore' ? firestore : {db: {}},
    setTimeout: fn => {timers.set(++clockId, fn); return clockId;}, clearTimeout: id => timers.delete(id), console: {warn: () => {}}});
  const stop = exports.watchReportAccess({uid: 'member', getIdTokenResult: (...args) => {tokenArgs = args; return Promise.resolve({claims: {}});}}, state => states.push(state));
  const snapshot = (name, value, fromCache = false) => listeners.get(`${name}/member`)?.receive({metadata: {fromCache}, exists: () => value !== null, data: () => value});
  return {states, listeners, timers, requests, stop, snapshot, catalog,
    get reads() {return reads;}, get tokenArgs() {return tokenArgs;},
    expire: () => {for (const fn of [...timers.values()]) fn();},
    fail: code => listeners.get('trailReportAccess/member').fail({code}),
  };
}
const member = session();
member.snapshot('admins', null); member.snapshot('trailReportAccess', {trailIds: ['cyprus']}, true);
await tick(); assert.equal(member.reads, 0, 'cached permissions must not authorize a session');
member.snapshot('trailReportAccess', {trailIds: ['cyprus']}); await tick();
assert.equal(member.states.at(-1).status, 'ready');
assert.deepEqual(Array.from(member.states.at(-1).access.trails, t => t.id), ['cyprus']);
assert.deepEqual(member.tokenArgs, [], 'opening must not force an authentication round trip');
member.snapshot('trailReportAccess', {trailIds: ['cyprus']}); await tick();
assert.equal(member.reads, 1, 'duplicate snapshots must not repeat catalog reads');
member.snapshot('trailReportAccess', {trailIds: []}); await tick();
assert.equal(member.states.at(-1).access.trails.length, 0, 'revocation removes previously available trails');
member.stop(); assert.equal(member.listeners.size, 0); assert.equal(member.timers.size, 0);
const admin = session(); admin.snapshot('admins', {}); admin.snapshot('trailReportAccess', null); await tick();
assert.equal(admin.states.at(-1).access.admin, true); assert.equal(admin.states.at(-1).access.trails.length, 2); admin.stop();
const failed = session(); failed.fail('permission-denied');
assert.equal(failed.states.at(-1).status, 'error'); assert.match(failed.states.at(-1).message, /sign out/);
assert.equal(failed.listeners.size, 0); assert.equal(failed.timers.size, 0);
const retry = session(); retry.snapshot('admins', null); retry.snapshot('trailReportAccess', {trailIds: ['cyprus']}); await tick();
assert.equal(retry.states.at(-1).status, 'ready'); retry.stop();
const slow = session({slowCatalog: true}); slow.snapshot('admins', null); slow.snapshot('trailReportAccess', {trailIds: ['cyprus']}); await tick();
slow.expire(); assert.equal(slow.states.at(-1).status, 'error', 'disconnected Firebase must not leave an indefinite spinner');
slow.snapshot('trailReportAccess', {trailIds: ['crete']}); await tick();
slow.requests[1].resolve(slow.catalog); await tick(); slow.requests[0].resolve(slow.catalog); await tick();
assert.deepEqual(Array.from(slow.states.at(-1).access.trails, t => t.id), ['crete'], 'an older request must not restore revoked access');
slow.stop();
const unmounted = session({slowCatalog: true}); unmounted.snapshot('admins', null); unmounted.snapshot('trailReportAccess', {trailIds: ['cyprus']}); await tick();
unmounted.stop(); const length = unmounted.states.length; unmounted.requests[0].resolve(unmounted.catalog); await tick();
assert.equal(unmounted.states.length, length, 'unmounted sessions ignore late responses');
console.log('PASS: member/admin access, cache isolation, deduplication, revocation, failure/retry, timeout, out-of-order completion and cleanup.');
