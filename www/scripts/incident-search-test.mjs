import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
function load(name, dependencies = {}) {
  const exports = {};
  vm.runInNewContext(ts.transpileModule(readFileSync(new URL(`../lib/${name}.ts`, import.meta.url), 'utf8'), {
    compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022},
  }).outputText, {exports, require: id => dependencies[id]});
  return exports;
}
const fuzzy = load('fuzzy-search');
const {incidentSearchText} = load('incident-search', {'./fuzzy-search': fuzzy});
const report = {id:'CY-12345', ticketReference:'E4-CY-00142', description:'Fallen signpost near Ágios forest', status:'reviewed', category:'signpost',
  priority:'high', passability:'difficult', authority:'Forestry department', origin:'organisation',
  forwardingReference:'CASE-9382', observedAtMs:Date.UTC(2026,10,11), receivedAt:{toDate:()=>new Date(2026,10,11)}};
const text = incidentSearchText(report, 'Signpost', 'Reviewed');
for (const query of ['', '  ', 'signpsot', 'fallen agios', 'FORREST', 'reviewd', 'high forestry', 'CY-12345', 'E4-CY-00142', 'CASE-9382', 'Organisation-created']) {
  assert.equal(fuzzy.matchesFuzzySearch(text, query), true, query);
}
for (const query of ['vegetation', 'resolved', 'fallen sea', 'CY-12346', 'E4-CY-00143', 'CASE-9383']) {
  assert.equal(fuzzy.matchesFuzzySearch(text, query), false, query);
}
const rows = [{text}, {text:incidentSearchText({...report,description:'Overgrown vegetation',id:'CY-777',authority:'',forwardingReference:''},'Vegetation','Received')}];
assert.equal(rows.filter(r=>fuzzy.matchesFuzzySearch(r.text,'overgown')).length,1);
assert.equal(rows.filter(r=>fuzzy.matchesFuzzySearch(r.text,'')).length,2,'Clearing restores all loaded rows');
console.log('PASS: incident typos, accents, multiple terms, category/status/reference search, exact numbers, no matches and clearing.');
