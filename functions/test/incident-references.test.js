import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp as adminApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {initializeApp,deleteApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,createUserWithEmailAndPassword} from 'firebase/auth';
import {getFunctions,connectFunctionsEmulator,httpsCallable} from 'firebase/functions';
import {incidentPrefix} from '../src/incident-references.js';

test('country prefixes use trail authority and preserve route codes',()=>{
  assert.equal(incidentPrefix('cyprus-e4',{}),'E4-CY');
  assert.equal(incidentPrefix('crete-e4',{}),'E4-GR');
  assert.equal(incidentPrefix('germany-e8',{country:'Germany'}),'E8-DE');
  assert.throws(()=>incidentPrefix('unknown',{}));
});
test('ticket allocation is authorized, atomic, idempotent, additive; duplicate linking accepts ticket references', {skip:!process.env.FIREBASE_AUTH_EMULATOR_HOST,timeout:90000}, async()=>{
  for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST'])assert.ok(process.env[key]?.startsWith('127.0.0.1:'));
  const suffix=Date.now(),projectId='demo-eurotrex';
  const admin=adminApp({projectId},`references-${suffix}`),db=getFirestore(admin),apps=[];
  const trailId=`references-${suffix}`, otherTrail=`other-${suffix}`;
  await db.doc(`trails/${trailId}`).set({name:'Reference test',verificationAuthority:{country:'Cyprus'}});
  await db.doc(`trails/${otherTrail}`).set({name:'Other trail',verificationAuthority:{country:'Cyprus'}});
  async function client(name){const app=initializeApp({projectId,apiKey:'demo-key',appId:`demo-${name}`},`${name}-${suffix}`);apps.push(app);const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});const user=(await createUserWithEmailAndPassword(auth,`${name}-${suffix}@example.test`,'TestPassword123!')).user;await adminAuth(admin).updateUser(user.uid,{emailVerified:true});await user.getIdToken(true);const f=getFunctions(app,'europe-west1');connectFunctionsEmulator(f,'127.0.0.1',5001);return {user,call:async(n,d)=>(await httpsCallable(f,n)(d)).data};}
  try {
    const manager=await client('reference-manager'),outsider=await client('reference-outsider');
    await db.doc(`trailReportAccess/${manager.user.uid}`).set({trailIds:[trailId]});
    const ids=[0,1,2].map(n=>`reference-${suffix}-${n}`),stamp=Timestamp.now();
    const original={trailId,description:'Preserve this incident',photos:[{id:'keep-photo',path:'unchanged'}],uploadState:'complete',receivedAt:stamp,updatedAt:stamp,status:'new',priority:'normal',publicWarning:false};
    for(const id of ids){await db.doc(`trailReports/${id}`).set(original);await db.doc(`trailReports/${id}/events/original`).set({note:'Keep original history'});}
    const allocate=reportIds=>manager.call('ensureIncidentReferences',{trailId,reportIds});
    await assert.rejects(outsider.call('ensureIncidentReferences',{trailId,reportIds:ids}),{code:'functions/permission-denied'});
    const [first,overlap]=await Promise.all([allocate(ids.slice(0,2)),allocate(ids.slice(1))]);
    assert.equal(first.references[ids[1]],overlap.references[ids[1]]);
    const {references}=await allocate(ids);
    assert.equal(new Set(Object.values(references)).size,3);
    assert.deepEqual((await allocate(ids)).references,references);
    for(const id of ids){assert.match(references[id],/^E4-CY-\d{5,}$/);const data=(await db.doc(`trailReports/${id}`).get()).data();const {ticketReference,ticketNumber,...preserved}=data;assert.deepEqual(preserved,original);assert.equal((await db.doc(`trailReports/${id}/events/original`).get()).data().note,'Keep original history');}
    await manager.call('reviewTrailReport',{reportId:ids[1],updatedAtMs:stamp.toMillis(),status:'duplicate',priority:'normal',duplicateOf:references[ids[0]],note:'Same issue',publicWarning:false});
    assert.equal((await db.doc(`trailReports/${ids[1]}`).get()).data().duplicateOf,ids[0]);
    await assert.rejects(manager.call('reviewTrailReport',{reportId:ids[0],updatedAtMs:stamp.toMillis(),status:'duplicate',priority:'normal',duplicateOf:references[ids[0]]}),{code:'functions/invalid-argument'});
    const otherId=`reference-other-${suffix}`;await db.doc(`trailReports/${otherId}`).set({...original,trailId:otherTrail});
    await assert.rejects(allocate([otherId]),{code:'functions/permission-denied'});
    assert.equal((await db.doc(`trailReports/${otherId}`).get()).data().ticketReference,undefined);
    assert.equal((await db.collection('trailReports').where('trailId','==',trailId).get()).size,3);
  } finally {await Promise.all(apps.map(deleteApp));}
});
