import test from 'node:test';
import assert from 'node:assert/strict';
import {validateEraRoute,revisionPayload,retainSectionVerification,fingerprint,validateRevision} from '../src/era-model.js';
const section=id=>({id,name:`Section ${id}`,sourceType:'member_organisation',source:'Survey',sourceUrl:'',attribution:'Survey owner permission'});
const draft=()=>revisionPayload({sectionSchema:1,sections:[section('a'),section('b')],segments:[{sectionId:'a',kind:'main',coordinates:[[33,35],[33.01,35]]},{sectionId:'b',kind:'main',coordinates:[[34,35],[34.01,35]]}],sourceType:'member_organisation',source:'Survey',attribution:'Permission',stageDecisions:{}});
test('ERA sections can be verified without elevation, stages or continuous country geometry',()=>{
 const payload=draft(),summary=validateEraRoute(payload);assert.deepEqual(summary.errors,[]);assert.ok(summary.totalDistanceKm<3);assert.equal(summary.sections.length,2);
 const mobile=validateRevision(payload,{stages:[],markers:[],excursions:[],detours:[]});assert.ok(mobile.errors.some(s=>s.includes('elevation')));assert.ok(mobile.errors.some(s=>s.includes('Gap')));
});
test('section changes invalidate only affected attestation; route order and membership invalidate whole-route binding',()=>{
 const payload=draft(),summary=validateEraRoute(payload),authority={organisationId:'org'};
 const previous={sectionVerifications:Object.fromEntries(summary.sections.map(s=>[s.id,{sectionHash:s.hash,authorityHash:fingerprint(authority)}]))};
 const changed=structuredClone(payload);changed.segments[1].coordinates[1][0]+=.001;
 assert.deepEqual(Object.keys(retainSectionVerification(previous,validateEraRoute(changed),authority)),['a']);
 const reordered={...payload,sections:[...payload.sections].reverse()};assert.notEqual(validateEraRoute(reordered).routeHash,summary.routeHash);
 assert.deepEqual(Object.keys(retainSectionVerification(previous,validateEraRoute(reordered),authority)),['b','a']);
 assert.deepEqual(retainSectionVerification(previous,summary,{organisationId:'other'}),{});
 assert.notEqual(validateEraRoute({...payload,segments:[...payload.segments].reverse()}).routeHash,summary.routeHash);
});
test('elevation and stage preparation retain route hashes, but coordinate edits do not',()=>{
 const payload=draft(),original=validateEraRoute(payload);
 const prepared={...payload,elevationSource:'Terrain',segments:payload.segments.map(s=>({...s,coordinates:s.coordinates.map(p=>[...p,100])})),stageEdits:[{id:'stop',name:'Stop',description:'',location:{longitude:33,latitude:35}}]};
 assert.equal(validateEraRoute(prepared).routeHash,original.routeHash);assert.notEqual(validateEraRoute(prepared).payloadHash,original.payloadHash);
 prepared.segments[0].coordinates[1][0]+=.001;assert.notEqual(validateEraRoute(prepared).routeHash,original.routeHash);
});
test('missing section identity, duplicate IDs and incomplete provenance fail',()=>{
 const payload=draft();assert.throws(()=>validateEraRoute({...payload,segments:[{...payload.segments[0],sectionId:'missing'}]}));
 assert.throws(()=>validateEraRoute({...payload,sections:[section('a'),section('a')]}));
 payload.sections[0].attribution='';assert.ok(validateEraRoute(payload).errors.some(s=>s.includes('attribution')));
});
