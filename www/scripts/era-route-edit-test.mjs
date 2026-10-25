import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
function load(name) {
  const exports={};
  const code=ts.transpileModule(readFileSync(new URL(`../lib/${name}.ts`,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  vm.runInNewContext(code,{exports});
  return exports;
}
const {decodeEditableRouteChunks}=load('route-geometry');
const metadata={pointFormat:['lat','lng','altitudeM'],pointStride:3,pointCount:3};
const result=decodeEditableRouteChunks(metadata,[{points:[34,32,800,35,33,null]},{points:[36,34,0]}]);
assert.equal(JSON.stringify(result),JSON.stringify([[32,34,800],[33,35],[34,36,0]]),'Preserve elevations, missing elevations and sea level across chunks');
assert.throws(()=>decodeEditableRouteChunks(metadata,[{points:[34,32,800,35,33,900]}]),/Incomplete/);
assert.throws(()=>decodeEditableRouteChunks({...metadata,pointCount:2},[{points:[34,32,NaN,35,33,800]}]),/elevation/);
const {parseRouteFile,routeSummary}=load('era-route-file');
assert.throws(()=>parseRouteFile('{"type":"MultiLineString","coordinates":[null]}','bad.geojson'),/two points/);
const segments=[{kind:'main',coordinates:[[32,34],[32.01,34]]},{kind:'main',coordinates:[[33,35],[33.01,35]]}];
const summary=routeSummary(segments);
assert.equal(summary.pointCount,4);
assert.ok(summary.distanceKm>1.8 && summary.distanceKm<1.9,'Do not count gaps between route sections as trail length');
console.log('Passed: editable elevation preservation, incomplete/invalid geometry rejection, malformed imports and section-aware distance.');
