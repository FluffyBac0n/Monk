import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const code = ts.transpileModule(readFileSync(new URL('../lib/incident-map-markers.ts', import.meta.url), 'utf8'), {
  compilerOptions: {module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022},
}).outputText;
const elements = [], active = new Set(), events = new Map(), moves = [], callbacks = [];
let sourceOptions, data, features = [], loaded = true, zoom = 8, layers = true, sourceRemoved = false;
const source = {setData: value => {data = value;}, getClusterExpansionZoom: (id, callback) => callbacks.push({id, callback})};
const map = {
  addSource: (_, options) => {sourceOptions = options;}, addLayer() {}, getSource: () => source,
  on: (name, fn) => events.set(name, fn), off: name => events.delete(name),
  isSourceLoaded: () => loaded, querySourceFeatures: () => features,
  getBounds: () => ({contains: coordinates => coordinates[0] < 100}),
  easeTo: move => moves.push(move), getZoom: () => zoom,
  project: () => ({x: 300, y: 180}), getContainer: () => ({getBoundingClientRect: () => ({width: 800, height: 400})}),
  getLayer: () => layers, removeLayer: () => {layers = false;}, removeSource: () => {sourceRemoved = true;},
};
class Marker {
  constructor({element}) {this.element = element;}
  setLngLat(coordinates) {this.coordinates = coordinates; return this;}
  addTo() {active.add(this); return this;}
  remove() {active.delete(this);}
  getElement() {return this.element;}
}
const exports = {}, selected = [];
vm.runInNewContext(code, {exports, Map, Set, document: {createElement: () => {
  const attrs = {}, handlers = {}, classes = new Set();
  const button = {attrs, handlers, classes, dataset: {},
    setAttribute: (key, value) => {attrs[key] = value;},
    addEventListener: (name, fn) => {handlers[name] = fn;},
    classList: {toggle: (name, on) => on ? classes.add(name) : classes.delete(name)}};
  elements.push(button); return button;
}}, require: name => name.endsWith('trail-reports') ? {reportCategories: {signpost: 'Signpost'}, reportStatuses: ['new', 'resolved']}
  : name.endsWith('ReportReview') ? {reportStatusLabels: {new: 'Received', resolved: 'Resolved'}}
  : {reportStatusMarker: status => `<svg>${status}</svg>`}});
const report = id => ({id, longitude: 33, latitude: 35, status: 'new', category: 'signpost', description: 'Fallen sign'});
const cluster = (revision, count = 2) => ({geometry: {type: 'Point', coordinates: [33,35]}, properties: {cluster: true, cluster_id: 7, point_count: count, revision}});
const render = () => events.get('render')?.();
const control = exports.createIncidentMarkers(map, {Marker}, id => selected.push(id));
assert.equal(sourceOptions.cluster, true);
control.update([report('a'), report('b')]);
assert.equal(data.features.length, 2);
features = [cluster(1), cluster(1)]; render();
assert.equal(active.size, 1, 'Deduplicate features shared by source tiles');
const clusterButton = [...active][0].element;
assert.equal(clusterButton.textContent, '2');
clusterButton.handlers.click({stopPropagation(){}});
callbacks.pop().callback(null, 12);
assert.equal(moves.at(-1).zoom, 12, 'Cluster clicks use Mapbox expansion zoom');
clusterButton.handlers.click({stopPropagation(){}});
control.update([report('b')]);
assert.equal(active.size, 0, 'Filter changes immediately remove stale counts');
const moveCount = moves.length;
callbacks.pop().callback(null, 14);
assert.equal(moves.length, moveCount, 'Ignore cluster clicks completed after filtering');
render(); assert.equal(active.size, 0, 'Ignore stale worker features');
features = [data.features[0]]; loaded = false; render(); assert.equal(active.size, 0);
loaded = true; render(); assert.equal(active.size, 1);
let individual = [...active][0].element;
assert.match(individual.innerHTML, /new/);
individual.handlers.click({stopPropagation(){}}); assert.deepEqual(selected, ['b']);
control.select('b'); assert.equal(individual.attrs['aria-pressed'], 'true');
assert.equal(moves.length, moveCount, 'Visible individual selection preserves zoom');
control.update([report('a'), report('b')]); features = [cluster(3)]; render();
control.select('a'); assert.equal(moves.at(-1).zoom, 16, 'A list selection reveals its clustered marker');
zoom = 16; features = data.features; render();
individual = [...active].find(marker => marker.element.attrs['aria-pressed'] === 'true').element;
assert.ok(individual.classes.has('is-selected'));
control.update([{...report('a'), status: 'resolved'}]); features = data.features; render();
assert.match([...active][0].element.innerHTML, /resolved/, 'Live report status updates retain the correct symbol');
control.update([]); features = []; render(); assert.equal(active.size, 0);
control.destroy(); control.destroy();
assert.equal(events.size, 0); assert.equal(layers, false); assert.equal(sourceRemoved, true);
console.log('PASS: cluster counts, expansion, filter races, duplicate tiles, selection, status updates, empty results and cleanup.');
