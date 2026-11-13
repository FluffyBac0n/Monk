import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
import vm from 'node:vm';
import ts from 'typescript';

const require = createRequire(import.meta.url);
const code = ts.transpileModule(readFileSync(new URL('../components/ReportReview.tsx', import.meta.url), 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX},
}).outputText;
const sample = (status, publicWarning) => ({id: 'fixture', status, publicWarning, priority: 'normal', authority: 'Trail team',
  updatedAt: {toMillis: () => 1}, uploadState: 'complete', trailId: 'fixture-trail', category: 'signpost',
  description: 'Fallen sign', passability: 'difficult', latitude: 35, longitude: 33});

// Exercise the component's actual controls, state and submitted request without Firebase.
function review(initial, drafts = new Map()) {
  let report = initial, cursor = 0, changed = false, effects = [], tree;
  const slots = [], calls = [], saved = [];
  const exports = {};
  vm.runInNewContext(code, {exports, require: name => {
    if (name === 'react') return {
      useState: value => {
        const index = cursor++;
        if (!(index in slots)) slots[index] = typeof value === 'function' ? value() : value;
        return [slots[index], next => {
          const value = typeof next === 'function' ? next(slots[index]) : next;
          if (!Object.is(slots[index], value)) {slots[index] = value; changed = true;}
        }];
      },
      useEffect: (effect, deps) => {
        const index = cursor++, previous = slots[index];
        if (!previous || deps.some((dep, i) => !Object.is(dep, previous[i]))) effects.push(effect);
        slots[index] = deps;
      },
    };
    if (name === '@/lib/trail-reports') return {reviewReport: async (_base, changes) => {calls.push(changes);}};
    if (name === './IncidentDrafts') return {useIncidentDraft: key => ({read: () => drafts.get(key), save:value => drafts.set(key,value), clear:() => drafts.delete(key)})};
    if (name === './ReportWorkflowDialog') return {ReportWorkflowDialog: () => null};
    if (name === './ReportSelect') return {ReportSelect: () => null};
    return require(name);
  }});
  function render() {
    for (let pass = 0; pass < 10; pass++) {
      cursor = 0; changed = false; effects = [];
      tree = exports.ReportReview({report, onSaved: text => saved.push(text)});
      effects.forEach(effect => effect());
      if (!changed) return tree;
    }
    throw new Error('Component did not settle.');
  }
  const nodes = node => !node || typeof node !== 'object' ? [] : Array.isArray(node)
    ? node.flatMap(nodes) : [node, ...nodes(node.props?.children)];
  const find = predicate => {const node = nodes(render()).find(predicate); assert.ok(node, 'Expected control'); return node;};
  return {
    calls, saved,
    checkbox: () => find(n => n.type === 'input' && n.props.type === 'checkbox').props,
    check: checked => find(n => n.type === 'input' && n.props.type === 'checkbox').props.onChange({target: {checked}}),
    action: value => find(n => n.props?.label === 'Next Steps').props.onChange(value),
    choices: () => find(n => n.props?.label === 'Next Steps').props.options.map(option => option.value),
    hasForm: () => nodes(render()).some(n => n.type === 'form'),
    hasCheckbox: () => nodes(render()).some(n => n.type === 'input' && n.props.type === 'checkbox'),
    openNote: () => find(n => n.type === 'button' && n.props.children === '+ Add internal note').props.onClick(),
    noteValue: () => find(n => n.type === 'textarea').props.value,
    note: text => find(n => n.type === 'textarea').props.onChange({target: {value: text}}),
    receive: next => {report = next; render();},
    submit: async () => {await find(n => n.type === 'form').props.onSubmit({preventDefault() {}}); render();},
  };
}

for (const origin of ['hiker', 'organisation']) {
  const form = review({...sample('new', origin === 'organisation' ? false : undefined), origin});
  assert.equal(form.hasForm(), false, 'No fields before choosing a next step');
  form.action('review');
  assert.equal(form.checkbox().checked, false, 'New incidents require explicit public approval');
  form.check(true); await form.submit();
  assert.equal(form.calls[0].status, 'reviewed');
  assert.equal(form.calls[0].publicWarning, true);
  assert.match(form.saved[0], /Saved/);
}
const privateReview = review(sample('new', false)); privateReview.action('review'); await privateReview.submit();
assert.equal(privateReview.calls[0].publicWarning, false);
const hidden = review(sample('reviewed', false)); hidden.action('note'); hidden.check(true); await hidden.submit();
assert.equal(hidden.calls[0].publicWarning, true);
const visible = review(sample('reviewed', true)); visible.action('forward'); await visible.submit();
assert.equal(visible.calls[0].status, 'forwarded'); assert.equal(visible.calls[0].publicWarning, true);
const legacy = review(sample('reviewed')); legacy.action('note'); assert.equal(legacy.checkbox().checked, true);
const withdraw = review(sample('forwarded', true)); withdraw.action('note'); withdraw.check(false); await withdraw.submit();
assert.equal(withdraw.calls[0].publicWarning, false);
for (const [action, status] of [['resolve', 'resolved'], ['dismiss', 'dismissed'], ['duplicate', 'duplicate']]) {
  const form = review(sample('reviewed', true)); form.action(action);
  assert.equal(form.hasCheckbox(), false);
  await form.submit(); assert.equal(form.calls[0].status, status); assert.equal(form.calls[0].publicWarning, false);
}
const reopened = review(sample('resolved', false));
assert.deepEqual(Array.from(reopened.choices()), ['', 'reopen', 'note']);
reopened.action('reopen'); reopened.check(true); reopened.note('Issue is active again'); await reopened.submit();
assert.equal(reopened.calls[0].status, 'reviewed'); assert.equal(reopened.calls[0].publicWarning, true);
const stale = review(sample('reviewed', false)); stale.action('note'); stale.check(true);
stale.receive({...sample('reviewed', false), updatedAt: {toMillis: () => 2}}); await stale.submit();
assert.equal(stale.calls.length, 0, 'A stale review cannot overwrite a newer publication choice');
const drafts = new Map(), original = sample('new', false), draftForm = review(original, drafts);
draftForm.action('review'); draftForm.openNote(); draftForm.note('Keep this unsaved note'); draftForm.hasForm();
const restored = review(original, drafts);
assert.equal(restored.noteValue(), 'Keep this unsaved note');
restored.action('forward'); assert.equal(restored.noteValue(), 'Keep this unsaved note');
restored.receive({...original, updatedAt:{toMillis:()=>2}}); await restored.submit();
assert.equal(restored.calls.length,0, 'Restoring a draft keeps its original concurrency version');
const fresh = review(original, drafts); await fresh.submit();assert.equal(drafts.size,0,'Successful save clears draft');
console.log('PASS: contextual actions, public warning choices, closure/reopening, draft remounts, retained notes, stale-write protection and draft clearing.');
