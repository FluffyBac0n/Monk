import test from 'node:test';
import assert from 'node:assert/strict';
import {parseGeoJSON,normaliseSegments,validateRevision,buildRelease,normaliseStageEdits,revisionPayload,hasEraRole,hasVerificationAuthority,verificationAttestation,verificationCriteria,verificationCriteriaVersion,fingerprint} from '../src/era-model.js';
const context={stages:[{id:'start',name:'Start',location:{longitude:33,latitude:35},services:{water:true}},{id:'finish',name:'Finish',location:{longitude:33.02,latitude:35}}],markers:[],excursions:[],detours:[],totalDistanceKm:null};
const body=()=>({segments:[{kind:'main',coordinates:[[33,35,100],[33.01,35,110],[33.02,35,90]]}],source:'Survey fixture',attribution:'Test licence',elevationSource:'Surveyed elevations',stageDecisions:{start:{confirmed:true},finish:{confirmed:true}},relatedRoutesReviewed:false,changesReviewed:false});
test('GeoJSON preserves disconnected parts and rejects polygons, invalid coordinates and empty geometry',()=>{
  const segments=parseGeoJSON({type:'FeatureCollection',features:[{type:'Feature',geometry:{type:'MultiLineString',coordinates:[[[33,35],[33.01,35]],[[34,35],[34.01,35]]]}}]});
  assert.equal(segments.length,2);
  assert.throws(()=>parseGeoJSON({type:'Polygon',coordinates:[]}),/LineString/);
  assert.throws(()=>normaliseSegments([{kind:'main',coordinates:[[181,35],[33,35]]}]),/Invalid/);
  assert.throws(()=>parseGeoJSON({type:'FeatureCollection',features:[]}),/between/);
});
test('release retains stable stage IDs and services and emits matching route distances',()=>{
  const result=validateRevision(body(),context);assert.deepEqual(result.errors,[]);
  const release=buildRelease(result);assert.equal(release.stages[0].id,'start');assert.equal(release.stages[0].services.water,true);
  assert.equal(release.stages[1].id,'finish');assert.equal(release.stages[1].accumulatedDistanceKm,result.totalDistanceKm);
  assert.equal(release.chunks[0].points.length,15);assert.equal(release.chunks[0].points[3],0);assert.equal(release.chunks[0].points.at(-1),0);
});
test('gaps, missing elevation and unchecked stage connections cannot become releases',()=>{
  for(const mutate of [b=>b.segments[0].coordinates.forEach(p=>p.pop()),b=>b.stageDecisions={},b=>b.segments.push({kind:'main',coordinates:[[34,35,10],[34.01,35,20]]}),b=>b.elevationSource='']){
    const b=body();mutate(b);const result=validateRevision(b,context);assert.ok(result.errors.length);assert.throws(()=>buildRelease(result));
  }
});
test('stage locations are preserved and distant pins require explicit off-route acknowledgement',()=>{
  const ctx=structuredClone(context);ctx.stages[1].location.latitude=35.02;
  const b=body();assert.ok(validateRevision(b,ctx).errors.some(e=>e.includes('off-route')));
  b.stageDecisions.finish.offRoute=true;assert.deepEqual(validateRevision(b,ctx).errors,[]);
  assert.equal(validateRevision(b,ctx).stages[1].location.latitude,35.02);
});
test('roles require an active, assigned organisation',()=>{
  const member={organisationId:'org',trailRoles:{cyprus:['editor']}};
  const org={id:'org',active:true,trailIds:['cyprus']};
  assert.equal(hasEraRole(member,org,'cyprus',['editor']),true);
  assert.equal(hasEraRole(member,{...org,active:false},'cyprus',['editor']),false);
  assert.equal(hasEraRole(member,org,'crete',['editor']),false);
  assert.equal(hasEraRole(member,org,'cyprus',['verifier']),false);
  assert.equal(fingerprint({b:2,a:1}),fingerprint({a:1,b:2}));
});
test('related routes are reanchored, recalculated and can be explicitly excluded',()=>{
  const ctx=structuredClone(context),b=body();b.relatedRoutesReviewed=true;
  const chunks=[{id:'0',chunkIndex:0,points:[35,33,100,0,1,35,33.02,90,1,0]}];
  ctx.excursions=[{id:'view',anchorType:'trail',connectionLocation:{longitude:33.01,latitude:35},chunkCount:1,_chunks:chunks}];
  ctx.detours=[{id:'branch',name:'Branch',chunkCount:1,pointStride:5,_chunks:chunks,routeDistanceKm:3,elevationUpM:30,elevationDownM:40,estimatedWalkingTimeMinutes:40,startConnection:{routeLocation:{longitude:33,latitude:35}},endConnection:{routeLocation:{longitude:33.02,latitude:35}}}];
  const result=validateRevision(b,ctx);assert.deepEqual(result.errors,[]);
  assert.ok(result.related.excursions[0].mainTrailDistanceKm>0);
  assert.equal(result.related.detours[0].replacedMainTrailDistanceKm,result.totalDistanceKm);
  assert.deepEqual(result.related.detours[0].affectedStageIds,['start','finish']);
  b.relatedDecisions={'detours:branch':{excluded:true}};assert.equal(validateRevision(b,ctx).related.detours.length,0);
});

test('draft stage edits and additions retain services and publish together without altering live context',()=>{
  const input={...body(),stageEdits:[{id:'start',name:'New start name',description:'Updated stop',location:{longitude:33,latitude:35},services:{water:false}},{id:'middle',name:'New stage',description:'Water point',location:{longitude:33.01,latitude:35}}]};
  input.stageDecisions.middle={confirmed:true};
  const payload=revisionPayload(input),result=validateRevision(payload,context);
  assert.deepEqual(result.errors,[]);
  const release=buildRelease(result);
  assert.deepEqual(release.stages.map(s=>s.id),['start','middle','finish']);
  assert.equal(release.stages[0].services.water,true);
  assert.equal(release.stages[0].name,'New start name');
  assert.equal(release.stages[1].description,'Water point');
  assert.equal(context.stages.length,2);
  assert.equal(context.stages[0].name,'Start');
  assert.equal(payload.stageEdits[0].services,undefined);
  delete payload.stageDecisions.middle;
  assert.ok(validateRevision(payload,context).errors.some(e=>e.includes('New stage')));
});
test('stage edits reject duplicates, invalid locations, blank names and excess entries',()=>{
  const stage={id:'test',name:'Stage',description:'',location:{longitude:33,latitude:35}};
  for(const input of [[stage,stage],[{...stage,location:{longitude:181,latitude:35}}],[{...stage,name:''}],Array(501).fill(stage)])assert.throws(()=>normaliseStageEdits(input));
});

test('source provenance cannot confer verification and only assigned organisation verifiers have authority',()=>{
  const member={organisationId:'org',trailRoles:{cyprus:['verifier']}},org={id:'org',active:true,trailIds:['cyprus']};
  assert.equal(hasVerificationAuthority(member,org,'cyprus',{organisationId:'org'}),true);
  assert.equal(hasVerificationAuthority(member,org,'cyprus',{organisationId:'other'}),false);
  assert.equal(hasVerificationAuthority(undefined,org,'cyprus',{organisationId:'org'}),false);
  assert.equal(hasVerificationAuthority(member,org,'other',{organisationId:'org'}),false);
  const value=revisionPayload({...body(),sourceType:'community',sourceUrl:'https://example.org/route',verification:{status:'verified'}});
  assert.equal(value.sourceType,'community');assert.equal(value.verification,undefined);
  assert.throws(()=>revisionPayload({...body(),sourceType:'community',sourceUrl:'javascript:alert(1)'}),/HTTP/);
  assert.throws(()=>revisionPayload({...body(),sourceType:'verified'}),/source type/);
  assert.equal('sourceType' in revisionPayload(body()),false,'Legacy payload hashes remain stable');
  assert.throws(()=>verificationAttestation({criteriaVersion:verificationCriteriaVersion,criteria:{}}),/criterion/);
  assert.equal(Object.keys(verificationAttestation({criteriaVersion:verificationCriteriaVersion,criteria:Object.fromEntries(verificationCriteria.map(key=>[key,true]))}).criteria).length,8);
});
