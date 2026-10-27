import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';
function load(name,dependencies={}) {
  const exports={};
  vm.runInNewContext(ts.transpileModule(readFileSync(new URL(`../lib/${name}.ts`,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText,{exports,require:id=>{if(id in dependencies)return dependencies[id];throw new Error(id);}});
  return exports;
}
const {auditSearchText,matchesAuditSearch}=load('audit-search');
const stamp=new Date(2026,9,27,14,32,9);
const index=auditSearchText({actorName:'Andréas Michaelides',actorEmail:'andreas@example.test',action:'revision_saved',recordId:'route-123',note:'Forest junction checked',createdAt:{toDate:()=>stamp}});
for(const query of ['Andreas','Michaeldies','Andres saved','27/10/2026','October 2026','14:32:09','2026-10-27','junction',String(stamp.getTime()),''])assert.equal(matchesAuditSearch(index,query),true,query);
for(const query of ['unrelated','Andreas dismissed','2027','14:42:09'])assert.equal(matchesAuditSearch(index,query),false,query);

let releaseId=null,version=1,chunks=0,calls=0;
const auth={currentUser:{uid:'editor'}};
const firestore={doc:(_,path,...rest)=>[path,...rest].join('/'),collection:(_,path)=>path,orderBy:v=>v,query:v=>v,
  getDoc:async path=>({exists:()=>true,data:()=>path.endsWith('routeMetadata/main')?{version,pointFormat:['lat','lng','altitudeM'],pointStride:3,pointCount:2,chunkCount:1}:path.includes('/releases/')?{revisionId:'released-revision'}:{name:'Trail',publishedReleaseId:releaseId}}),
  getDocs:async()=>{chunks++;return {size:1,docs:[{data:()=>({points:[34,32,800,35,33,900]})}]};}};
const loader=load('era-current-route',{'firebase/firestore':firestore,'./firebase':{auth,db:{}},'./route-geometry':load('route-geometry'),'./era':{eraCall:async(name,args)=>{calls++;assert.equal(args.payloadOnly,true);return {payload:{segments:[{kind:'main',coordinates:[[32,34,800],[33,35,900]]},{kind:'alternative',coordinates:[[32,34,800],[34,36,950]]}]}};}}});
await Promise.all([loader.loadCurrentEraRoute('trail'),loader.loadCurrentEraRoute('trail')]);assert.equal(chunks,1);
await loader.loadCurrentEraRoute('trail');assert.equal(chunks,1,'Unchanged public points are reused');
version++;await loader.loadCurrentEraRoute('trail');assert.equal(chunks,2,'Updated metadata invalidates cache');
releaseId='release-one';const current=await loader.loadCurrentEraRoute('trail');assert.equal(current.payload.segments.length,2,'Preserve original alternative segments');
await loader.loadCurrentEraRoute('trail');assert.equal(calls,1,'Published payload reused without review validation');
releaseId='release-two';await loader.loadCurrentEraRoute('trail');assert.equal(calls,2);
auth.currentUser.uid='another';await loader.loadCurrentEraRoute('trail');assert.equal(calls,3,'Accounts cannot share private payload cache');
loader.clearCurrentEraRoutes();await loader.loadCurrentEraRoute('trail');assert.equal(calls,4,'Access changes invalidate session cache');
console.log('Passed: fuzzy names/actions, dates/timestamps, combined search, geometry deduplication, release/metadata invalidation, alternatives and account isolation.');
