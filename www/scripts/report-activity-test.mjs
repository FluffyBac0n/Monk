import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
const code = ts.transpileModule(readFileSync(new URL('../components/ReportActivityDialog.tsx', import.meta.url), 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX},
}).outputText;
function render(overrides = {}) {
  const effects = [], document = {body: {style: {overflow: 'auto'}}, activeElement: {focus: () => restored++}};
  let closed = 0, shown = 0, restored = 0, requests = 0;
  const exports = {};
  vm.runInNewContext(code, {exports, document, require: name => name === 'react' ? {
    useRef: () => ({current: {showModal: () => shown++, close: () => closed++}}), useId: () => 'activity-title', useEffect: effect => effects.push(effect),
  } : name === 'react/jsx-runtime' ? {jsx: (type, props) => ({type, props}), jsxs: (type, props) => ({type, props})}
    : {reportStatusLabels: {new: 'Received', reviewed: 'Reviewed'}}});
  const tree = exports.ReportActivityDialog({open: true, onClose: () => requests++, reference: 'CY-0001', events: [], loading: false, error: '', ...overrides});
  return {tree, document, start: () => effects[0](), get shown(){return shown;}, get closed(){return closed;}, get restored(){return restored;}, get requests(){return requests;}};
}
const text = node => node == null || typeof node === 'boolean' ? '' : typeof node !== 'object' ? String(node) : Array.isArray(node) ? node.map(text).join(' ') : text(node.props.children);
const modal = render(); const cleanup = modal.start();
assert.equal(modal.shown, 1); assert.equal(modal.document.body.style.overflow, 'hidden');
assert.match(text(modal.tree), /No activity recorded yet/);
let prevented = false; modal.tree.props.onCancel({preventDefault: () => {prevented = true;}});
assert.equal(prevented, true); assert.equal(modal.requests, 1, 'Escape requests a state change');
modal.tree.props.onClick({target: {}, currentTarget: {}}); assert.equal(modal.requests, 1, 'Content clicks keep the log open');
const backdrop = {}; modal.tree.props.onClick({target: backdrop, currentTarget: backdrop}); assert.equal(modal.requests, 2);
cleanup(); assert.equal(modal.closed, 1); assert.equal(modal.restored, 1); assert.equal(modal.document.body.style.overflow, 'auto');
const hidden = render({open: false}); hidden.start(); assert.equal(hidden.shown, 0);
assert.match(text(render({loading: true}).tree), /Loading activity/);
const event = {id: 'e1', previousStatus: 'new', status: 'reviewed', action: 'review', actorEmail: 'reviewer@example.test', createdAt: {toDate: () => new Date('2026-11-14T08:00:00Z')}, note: 'Checked signpost', authority: 'Trail team', forwardingReference: 'REF-1'};
const loaded = text(render({events: [event]}).tree);
for (const value of ['Received → Reviewed', 'Checked signpost', 'reviewer@example.test', 'Trail team', 'REF-1']) assert.ok(loaded.includes(value));
const denied = text(render({events: [event], error: 'Access unavailable'}).tree);
assert.match(denied, /Access unavailable/); assert.ok(!denied.includes('Checked signpost'), 'Access errors do not expose cached activity');
console.log('PASS: activity modal opening, Escape/backdrop closing, focus restoration, loading, empty, history and access-error states.');
