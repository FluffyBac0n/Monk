import test from 'node:test';
import assert from 'node:assert/strict';
import {initializeApp as adminApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {getAuth as adminAuth} from 'firebase-admin/auth';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, signInAnonymously, createUserWithEmailAndPassword} from 'firebase/auth';
import {getFunctions, connectFunctionsEmulator, httpsCallable} from 'firebase/functions';
import {getStorage, connectStorageEmulator, ref, uploadBytes} from 'firebase/storage';
import sharp from 'sharp';
import {createHash} from 'node:crypto';
import {getStorage as adminStorage} from 'firebase-admin/storage';
const enabled = !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
test('full submission → private images → trail review → forwarding → revocation', {skip:!enabled, timeout:90000}, async () => {
 const projectId='demo-eurotrex';
 const admin=adminApp({projectId,storageBucket:`${projectId}.appspot.com`},'flow-admin');
 const db=getFirestore(admin);
 await db.doc('trails/cyprus-e4').set({name:'Cyprus E4'});
 await db.doc('trails/crete-e4').set({name:'Crete E4'});
 const apps=[];
 async function client(name,email) {
  const app=initializeApp({projectId,apiKey:'demo-key',appId:`demo-${name}`,storageBucket:`${projectId}.appspot.com`},name); apps.push(app);
  const auth=getAuth(app); connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
  const user=(email ? await createUserWithEmailAndPassword(auth,email,'TestPassword123!') : await signInAnonymously(auth)).user;
  if(email) {await adminAuth(admin).updateUser(user.uid,{emailVerified:true}); await user.getIdToken(true);}
  const functions=getFunctions(app,'europe-west1');connectFunctionsEmulator(functions,'127.0.0.1',5001);
  const storage=getStorage(app);connectStorageEmulator(storage,'127.0.0.1',9199);
  return {user,storage,call:async(name,data)=>(await httpsCallable(functions,name)(data)).data};
 }
 try {
  const hiker=await client('flow-hiker');
  const staff=await client('flow-staff','staff-flow@example.com');
  const other=await client('flow-other','other-flow@example.com');
  const owner=await client('flow-owner','admin-flow@example.com');
  await db.doc(`admins/${owner.user.uid}`).set({});
  await owner.call('setTrailReportAccess',{email:staff.user.email,trailId:'cyprus-e4',grant:true});
  await owner.call('setTrailReportAccess',{email:other.user.email,trailId:'crete-e4',grant:true});
  const reportId='flow-report';
  const data={reportId,trailId:'cyprus-e4',category:'signpost',description:'Broken sign at junction',passability:'difficult',latitude:34.89,longitude:32.87,locationSource:'gps',accuracyM:5,observedAtMs:Date.now(),photoIds:['photo_0'],contactEmail:'private@example.com'};
  await hiker.call('beginTrailReport',data);
  await assert.rejects(hiker.call('finalizeTrailReport',{reportId}));
  const image=await sharp({create:{width:100,height:100,channels:3,background:'#e36a18'}}).jpeg().toBuffer();
  const uploadPath=`trail-report-uploads/${hiker.user.uid}/${reportId}/photo_0/photo.jpg`;
  const checksum={id:'photo_0',md5Hash:createHash('md5').update(image).digest('base64'),byteLength:image.length};
  // A changed upload of the same byte length catches corruption that size
  // checks alone cannot detect.
  const corrupt=Buffer.from(image);corrupt[corrupt.length-3]^=1;
  await uploadBytes(ref(hiker.storage,uploadPath),corrupt,{contentType:'image/jpeg'});
  await assert.rejects(other.call('finalizeTrailReport',{reportId,photoChecksums:[checksum]}),{code:'functions/permission-denied'});
  await assert.rejects(hiker.call('finalizeTrailReport',{reportId,photoChecksums:[]}),{code:'functions/invalid-argument'});
  assert.equal((await adminStorage(admin).bucket().file(uploadPath).exists())[0],true);
  await assert.rejects(hiker.call('finalizeTrailReport',{reportId,photoChecksums:[checksum]}),error=>
   error.code==='functions/failed-precondition' && error.message.includes('integrity check'));
  assert.equal((await adminStorage(admin).bucket().file(uploadPath).exists())[0],false);
  assert.equal((await db.doc(`trailReports/${reportId}`).get()).data().uploadState,'uploading');
  assert.equal((await hiker.call('trailReportReceipt',{reportId})).received,false);
  assert.equal((await db.doc(`trailReports/${reportId}`).collection('events').get()).size,0);
  await uploadBytes(ref(hiker.storage,uploadPath),image,{contentType:'image/jpeg'});
  // The existing object is verified on retry, rather than assumed to be valid.
  assert.equal((await hiker.call('finalizeTrailReport',{reportId,photoChecksums:[checksum]})).received,true);
  assert.equal((await hiker.call('beginTrailReport',data)).received,true);
  assert.equal((await hiker.call('finalizeTrailReport',{reportId})).received,true);
  assert.equal((await db.doc(`trailReports/${reportId}`).collection('events').get()).size,1);
  await assert.rejects(hiker.call('trailReportPhoto',{reportId,photoId:'photo_0'}));
  await assert.rejects(other.call('trailReportPhoto',{reportId,photoId:'photo_0'}));
  assert.ok((await staff.call('trailReportPhoto',{reportId,photoId:'photo_0'})).data.length>0);
  const current=(await db.doc(`trailReports/${reportId}`).get()).data();
  await assert.rejects(other.call('reviewTrailReport',{reportId,updatedAtMs:current.updatedAt.toMillis(),status:'resolved',priority:'normal',note:'No'}));
  await staff.call('reviewTrailReport',{reportId,updatedAtMs:current.updatedAt.toMillis(),status:'forwarded',priority:'high',authority:'Trail maintenance team',note:'Sent for repair'});
  const receipt=await hiker.call('trailReportReceipt',{reportId}); assert.equal(receipt.status,'forwarded'); assert.equal(receipt.description,undefined);
  await assert.rejects(staff.call('setTrailReportAccess',{email:other.user.email,trailId:'cyprus-e4',grant:true}));
  await owner.call('setTrailReportAccess',{email:staff.user.email,trailId:'cyprus-e4',grant:false});
  await assert.rejects(staff.call('trailReportPhoto',{reportId,photoId:'photo_0'}));
  assert.equal((await db.doc(`trailReports/${reportId}`).get()).data().trailId,'cyprus-e4');
  // Already-distributed builds still submit photos without the new manifest.
  const legacyId='legacy-photo-report';
  await hiker.call('beginTrailReport',{...data,reportId:legacyId});
  await uploadBytes(ref(hiker.storage,`trail-report-uploads/${hiker.user.uid}/${legacyId}/photo_0/photo.jpg`),image,{contentType:'image/jpeg'});
  assert.equal((await hiker.call('finalizeTrailReport',{reportId:legacyId})).received,true);
 } finally {await Promise.all(apps.map(deleteApp));}
});
