import {readFileSync} from 'node:fs';
import test from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, getDocs, collection, query, where, updateDoc} from 'firebase/firestore';
import {ref, uploadBytes, getBytes} from 'firebase/storage';
const projectId = 'demo-eurotrex';
const enabled = !!process.env.FIRESTORE_EMULATOR_HOST;
test('Firestore report permissions enforce trail boundaries, including audit and membership', {skip:!enabled}, async () => {
 const env = await initializeTestEnvironment({projectId, firestore:{rules:readFileSync('../www/firestore.rules','utf8')}, storage:{rules:readFileSync('../www/storage.rules','utf8')}});
 try {
  await env.withSecurityRulesDisabled(async context => {
   const db=context.firestore();
   for (const [path,value] of Object.entries({
    'admins/admin':{}, 'trailReportAccess/cyprus':{trailIds:['cyprus-e4']}, 'trailReportAccess/crete':{trailIds:['crete-e4']},
    'trailReports/one':{trailId:'cyprus-e4',reporterUid:'hiker',uploadState:'complete',photoIds:['photo_0']},
    'trailReports/two':{trailId:'crete-e4',reporterUid:'other',uploadState:'complete'},
    'trailReports/pending':{trailId:'cyprus-e4',reporterUid:'hiker',uploadState:'uploading',photoIds:['photo_0']},
    'trailReports/one/events/submitted':{action:'submitted'},
   })) await setDoc(doc(db,path),value);
  });
  const user=id=>env.authenticatedContext(id,{email:`${id}@example.com`,email_verified:true}).firestore();
  await assertSucceeds(getDoc(doc(user('cyprus'),'trailReports/one')));
  await assertSucceeds(getDoc(doc(user('admin'),'trailReports/two')));
  await assertFails(getDoc(doc(user('crete'),'trailReports/one')));
  await assertFails(getDoc(doc(user('hiker'),'trailReports/one')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'trailReports/one')));
  await assertFails(getDoc(doc(env.authenticatedContext('cyprus',{email_verified:false}).firestore(),'trailReports/one')));
  await assertFails(getDocs(collection(user('cyprus'),'trailReports')));
  await assertSucceeds(getDocs(query(collection(user('cyprus'),'trailReports'),where('trailId','==','cyprus-e4'),where('uploadState','==','complete'))));
  await assertFails(updateDoc(doc(user('cyprus'),'trailReports/one'),{trailId:'crete-e4'}));
  await assertFails(setDoc(doc(user('cyprus'),'trailReportAccess/cyprus'),{trailIds:['crete-e4']}));
  await assertSucceeds(getDoc(doc(user('cyprus'),'trailReports/one/events/submitted')));
  await assertFails(getDoc(doc(user('crete'),'trailReports/one/events/submitted')));
  await assertFails(getDoc(doc(user('cyprus'),'trailReports/pending')));
  const storage=env.authenticatedContext('hiker').storage();
  await assertSucceeds(uploadBytes(ref(storage,'trail-report-uploads/hiker/pending/photo_0/photo.jpg'),new Uint8Array([1,2]),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage,'trail-report-uploads/hiker/pending/photo_1/photo.jpg'),new Uint8Array([1,2]),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage,'trail-report-uploads/other/pending/photo_0/photo.jpg'),new Uint8Array([1,2]),{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage,'trail-report-uploads/hiker/pending/photo_0/photo.jpg'),new Uint8Array([1,2]),{contentType:'image/jpeg'}));
  await env.withSecurityRulesDisabled(async c => uploadBytes(ref(c.storage(),'trail-report-media/one/photo_0.jpg'),new Uint8Array([1,2]),{contentType:'image/jpeg'}));
  await assertSucceeds(getBytes(ref(env.authenticatedContext('cyprus',{email_verified:true,email:'cyprus@example.com'}).storage(),'trail-report-media/one/photo_0.jpg')));
  await assertFails(getBytes(ref(env.authenticatedContext('crete',{email_verified:true,email:'crete@example.com'}).storage(),'trail-report-media/one/photo_0.jpg')));
  await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(),'trailReportAccess/cyprus'),{trailIds:[]}));
  await assertFails(getDoc(doc(user('cyprus'),'trailReports/one')));
 } finally {await env.cleanup();}
});
