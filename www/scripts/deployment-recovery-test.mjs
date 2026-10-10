import assert from 'node:assert/strict';
import vm from 'node:vm';
import {deploymentRecovery} from '../lib/deployment-recovery.ts';

function page({href = 'https://example.test/trail-reports?status=new#report-42', online = true, stored = '0', blockedStorage = false} = {}) {
  const handlers = {}, navigations = [];
  const location = {href, origin: new URL(href).origin, replace: next => navigations.push(next)};
  const context = {URL, Date, navigator: {onLine: online}, window: {location, addEventListener: (name, fn) => {handlers[name] = fn;}}, sessionStorage: {
    getItem: () => {if (blockedStorage) throw Error('blocked'); return stored;},
    setItem: (_key, value) => {stored = value;},
  }};
  vm.runInNewContext(deploymentRecovery, context);
  return {handlers, navigations};
}

const missing = {target: {tagName: 'SCRIPT', src: 'https://example.test/_next/static/chunks/old.js'}};
const initial = page();
initial.handlers.error(missing);
initial.handlers.error(missing);
assert.equal(initial.navigations.length, 1);
const refreshed = new URL(initial.navigations[0]);
assert.equal(refreshed.pathname, '/trail-reports');
assert.equal(refreshed.searchParams.get('status'), 'new');
assert.equal(refreshed.hash, '#report-42');
assert.ok(Number(refreshed.searchParams.get('_refresh')));
const retry = page({href: refreshed.href, blockedStorage: true});
retry.handlers.error(missing);
assert.equal(retry.navigations.length, 0, 'do not loop if a reload also fails');

for (const message of ['Importing a module script failed.', 'Failed to fetch dynamically imported module: https://example.test/old.js', 'Loading chunk 42 failed.']) {
  const p = page();
  p.handlers.unhandledrejection({reason: new Error(message)});
  assert.equal(p.navigations.length, 1, message);
}
const unrelated = page();
unrelated.handlers.error({target: {tagName: 'IMG', src: missing.target.src}});
unrelated.handlers.error({target: {tagName: 'SCRIPT', src: 'https://third-party.test/_next/static/old.js'}});
unrelated.handlers.unhandledrejection({reason: new Error('Firebase permission denied')});
assert.equal(unrelated.navigations.length, 0, 'unrelated errors must not discard user input');
const offline = page({online: false});
offline.handlers.error(missing);
assert.equal(offline.navigations.length, 0);
const recent = page({stored: String(Date.now())});
recent.handlers.error(missing);
assert.equal(recent.navigations.length, 0);
console.log('PASS: stale assets recover once; preserve URL; no loops, offline reloads or unrelated-error reloads.');
