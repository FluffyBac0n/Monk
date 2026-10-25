// Emulator-only fixture for manual browser QA. Never connects to a live project.
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {createEraService} from '../src/era-service.js';
for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST'])if(!process.env[key]?.startsWith('127.0.0.1:'))throw new Error('Loopback emulators are required.');
initializeApp({projectId:'demo-eurotrex',storageBucket:'demo-eurotrex.appspot.com'});
const db=getFirestore(),auth=getAuth();
let user;try{user=await auth.getUserByEmail('era-preview@example.test');}catch{user=await auth.createUser({email:'era-preview@example.test',password:'DemoPreview123!',emailVerified:true});}
await db.doc(`admins/${user.uid}`).set({});
const trailId='era-preview';
await db.doc(`trails/${trailId}`).set({name:'ERA browser test trail'});
for(const [id,sequence,longitude] of [['start',1,32.87],['finish',2,32.89]])await db.doc(`trails/${trailId}/stages/${id}`).set({sequence,name:id==='start'?'Forest junction':'Village stop',location:{latitude:34.89,longitude},services:{water:true}});
const era=createEraService({db,bucket:getStorage().bucket(),authService:auth});
const workspace=await db.doc(`eraWorkspaces/${trailId}`).get();
if(!workspace.exists)await era.saveEraRevision({auth:{uid:user.uid,token:{email:user.email,email_verified:true}},data:{trailId,expectedRevisionId:null,segments:[{kind:'main',coordinates:[[32.87,34.89,800],[32.88,34.89,850],[32.89,34.89,820]]}],source:'Isolated browser fixture',attribution:'QA fixture',elevationSource:'Synthetic test elevation',stageDecisions:{start:{confirmed:true},finish:{confirmed:true}}}});
console.log('ERA emulator browser fixture ready.');
