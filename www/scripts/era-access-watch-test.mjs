import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../lib/era-access-watch.ts', import.meta.url), 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022},
}).outputText;
const tick = () => new Promise(resolve => setImmediate(resolve));
function session() {
  const listeners = new Map(), requests = [], events = [], timers = new Map();
  let clears = 0, timerId = 0;
  const exports = {};
  const dependencies = {
    'firebase/firestore': {doc: (_, name) => name, onSnapshot: (name, _, next, fail) => {
      listeners.set(name, {next, fail}); return () => listeners.delete(name);
    }},
    './firebase': {db: {}},
    './era': {eraCall: () => new Promise((resolve, reject) => requests.push({resolve, reject}))},
    './era-current-route': {clearCurrentEraRoutes: () => clears++},
  };
  vm.runInNewContext(code, {exports, require: name => dependencies[name],
    setTimeout: fn => {timers.set(++timerId, fn); return timerId;}, clearTimeout: id => timers.delete(id)});
  const stop = exports.watchEraAccess('member', {
    pending: () => events.push('pending'), receive: access => events.push(access), fail: () => events.push('error'),
  });
  const snapshot = (name, data, fromCache = false) => listeners.get(name)?.next({data: () => data, metadata: {fromCache}});
  const initial = () => {snapshot('admins', null); snapshot('eraMembers', {roles: ['incident_manager']}); snapshot('trailReportAccess', {trailIds: ['cyprus']});};
  return {events, requests, listeners, timers, stop, snapshot, initial, get clears() {return clears;}};
}
const stable = session();
stable.snapshot('admins', null, true);
stable.snapshot('eraMembers', {}, true);
stable.snapshot('trailReportAccess', {}, true);
assert.equal(stable.requests.length, 0, 'Cached permissions cannot authorize access');
stable.initial();
assert.equal(stable.requests.length, 1, 'Bootstrap waits for all permission documents and loads once');
stable.requests[0].resolve({trails: ['cyprus']}); await tick();
const renderedEvents = stable.events.length;
for (let i = 0; i < 3; i++) stable.initial();
assert.equal(stable.requests.length, 1, 'Identical server/reconnect snapshots do not reload access');
assert.equal(stable.events.length, renderedEvents, 'Unchanged snapshots never clear the rendered workspace');
assert.equal(stable.clears, 1, 'Unchanged permissions preserve route caches');
stable.snapshot('trailReportAccess', {trailIds: []});
assert.equal(stable.events.at(-1), 'pending', 'Revocation immediately clears previously granted access');
stable.snapshot('eraMembers', {roles: []});
stable.requests[2].resolve({trails: []}); await tick();
stable.requests[1].resolve({trails: ['cyprus']}); await tick();
assert.equal(stable.events.at(-1).trails.length, 0, 'Late permission responses cannot restore revoked access');
stable.stop(); assert.equal(stable.listeners.size, 0); assert.equal(stable.timers.size, 0);
const failed = session(); failed.initial();
failed.listeners.get('admins').fail(new Error('permission-denied'));
failed.requests[0].resolve({trails: ['cyprus']}); await tick();
assert.equal(failed.events.at(-1), 'error'); assert.equal(failed.listeners.size, 0);
const retry = session(); retry.initial(); retry.requests[0].resolve({trails: ['cyprus']}); await tick();
assert.equal(retry.events.at(-1).trails[0], 'cyprus', 'A fresh subscription recovers after retry'); retry.stop();
const slow = session(); for (const expire of [...slow.timers.values()]) expire();
assert.equal(slow.events.at(-1), 'error', 'Disconnected permission checks do not spin indefinitely');
const unmounted = session(); unmounted.initial(); unmounted.stop();
const length = unmounted.events.length; unmounted.requests[0].resolve({trails: ['cyprus']}); await tick();
assert.equal(unmounted.events.length, length, 'Unmounted sessions ignore late completions');
console.log('PASS: stable workspace on duplicate snapshots, single bootstrap, cache isolation, immediate revocation, stale-response protection, retry, timeout and cleanup.');
