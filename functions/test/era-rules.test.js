import {readFileSync} from 'node:fs';
import test from 'node:test';
import {initializeTestEnvironment,assertSucceeds,assertFails} from '@firebase/rules-unit-testing';
import {doc,setDoc,getDoc,getDocs,collection,query,where,updateDoc} from 'firebase/firestore';
const enabled=!!process.env.FIRESTORE_EMULATOR_HOST;
test('ERA rules protect drafts, staged chunks, immutable releases and trail-scoped audit',{skip:!enabled},async()=>{
  const env=await initializeTestEnvironment({projectId:'demo-eurotrex',firestore:{rules:readFileSync('../www/firestore.rules','utf8')}});
  try {
    await env.withSecurityRulesDisabled(async c=>{for(const [p,v] of Object.entries({
      'admins/rule-admin':{},'trails/rules-era':{name:'Rule fixture',publishedReleaseId:'live'},
      'eraOrganisations/rules-org':{active:true,trailIds:['rules-era']},
      'eraMembers/rule-editor':{organisationId:'rules-org',trailRoles:{'rules-era':['editor']}},
      'eraWorkspaces/rules-era/revisions/draft':{state:'draft'},
      'eraAudit/rules-event':{trailId:'rules-era',action:'revision_saved'},
      'eraAudit/rules-other':{trailId:'rules-other',action:'revision_saved'},
      'trails/rules-era/releases/live':{published:true},
      'trails/rules-era/releases/live/routeChunks/0':{points:[35,33]},
      'trails/rules-era/releases/staging/routeChunks/0':{points:[35,33]},
    }))await setDoc(doc(c.firestore(),p),v);});
    const user=id=>env.authenticatedContext(id,{email:`${id}@example.test`,email_verified:true}).firestore(),publicDb=env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(publicDb,'eraWorkspaces/rules-era/revisions/draft')));
    await assertFails(getDoc(doc(publicDb,'trails/rules-era/releases/staging/routeChunks/0')));
    await assertSucceeds(getDoc(doc(publicDb,'trails/rules-era/releases/live/routeChunks/0')));
    await assertSucceeds(getDocs(query(collection(publicDb,'trails/rules-era/releases'),where('published','==',true))));
    await assertSucceeds(getDoc(doc(user('rule-editor'),'eraWorkspaces/rules-era/revisions/draft')));
    await assertFails(getDoc(doc(user('rule-other'),'eraWorkspaces/rules-era/revisions/draft')));
    await assertSucceeds(getDocs(query(collection(user('rule-editor'),'eraAudit'),where('trailId','==','rules-era'))));
    await assertFails(getDoc(doc(user('rule-editor'),'eraAudit/rules-other')));
    await assertFails(setDoc(doc(user('rule-admin'),'eraAudit/forged'),{trailId:'rules-era'}));
    await assertFails(updateDoc(doc(user('rule-admin'),'trails/rules-era'),{publishedReleaseId:'staging'}));
    await assertFails(updateDoc(doc(user('rule-admin'),'trails/rules-era/releases/live'),{published:false}));
    await assertFails(setDoc(doc(user('rule-editor'),'eraMembers/rule-editor'),{trailRoles:{'rules-era':['verifier']}}));
    await env.withSecurityRulesDisabled(c=>updateDoc(doc(c.firestore(),'eraOrganisations/rules-org'),{active:false}));
    await assertFails(getDoc(doc(user('rule-editor'),'eraWorkspaces/rules-era/revisions/draft')));
  }finally{await env.cleanup();}
});
