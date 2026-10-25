// Emulator-only fixture for manual browser QA. Never connects to a live project.
import {initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore,Timestamp} from 'firebase-admin/firestore';
import {getStorage} from 'firebase-admin/storage';
import {createEraService} from '../src/era-service.js';
import {distanceKm} from '../src/era-model.js';
for(const key of ['FIRESTORE_EMULATOR_HOST','FIREBASE_AUTH_EMULATOR_HOST','FIREBASE_STORAGE_EMULATOR_HOST'])if(!process.env[key]?.startsWith('127.0.0.1:'))throw new Error('Loopback emulators are required.');
initializeApp({projectId:'demo-eurotrex',storageBucket:'demo-eurotrex.appspot.com'});
const db=getFirestore(),auth=getAuth();
let user;try{user=await auth.getUserByEmail('era-preview@example.test');}catch{user=await auth.createUser({email:'era-preview@example.test',password:'DemoPreview123!',emailVerified:true});}
await db.doc(`admins/${user.uid}`).set({});
const trailId='era-preview';
await db.doc(`trails/${trailId}`).set({name:'ERA browser test trail'});
const route=[[32.87,34.89,800],[32.88,34.89,850],[32.89,34.89,820]];
const cumulative=[0];for(let i=1;i<route.length;i++)cumulative.push(cumulative.at(-1)+distanceKm(route[i-1],route[i]));
await db.doc(`trails/${trailId}/routeMetadata/main`).set({version:1,pointStride:5,pointFormat:['lat','lng','altitudeM','distanceKm','reverseDistanceKm'],pointCount:route.length,chunkCount:1});
await db.doc(`trails/${trailId}/routeChunks/0`).set({chunkIndex:0,points:route.flatMap((p,i)=>[p[1],p[0],p[2],cumulative[i],cumulative.at(-1)-cumulative[i]])});

for(const [id,sequence,longitude] of [['start',1,32.87],['finish',2,32.89]])await db.doc(`trails/${trailId}/stages/${id}`).set({sequence,name:id==='start'?'Forest junction':'Village stop',location:{latitude:34.89,longitude},services:{water:true}});
const era=createEraService({db,bucket:getStorage().bucket(),authService:auth});
const workspace=await db.doc(`eraWorkspaces/${trailId}`).get();
if(!workspace.exists)await era.saveEraRevision({auth:{uid:user.uid,token:{email:user.email,email_verified:true}},data:{trailId,expectedRevisionId:null,segments:[{kind:'main',coordinates:[[32.87,34.89,800],[32.88,34.89,850],[32.89,34.89,820]]}],source:'Isolated browser fixture',attribution:'QA fixture',elevationSource:'Synthetic test elevation',stageDecisions:{start:{confirmed:true},finish:{confirmed:true}}}});
// One isolated marker for every review status, for map/filter browser QA.
for(const [index,status] of ['new','reviewed','forwarded','resolved','duplicate','dismissed'].entries())await db.doc(`trailReports/preview-status-${status}`).set({
  trailId,origin:'organisation',category:'signpost',description:`Synthetic ${status} signpost report`,
  passability:'unsure',latitude:34.89+(index%2?0.001:-0.001),longitude:32.872+index*0.003,
  locationSource:'map',observedAtMs:Date.now(),receivedAt:Timestamp.now(),updatedAt:Timestamp.now(),
  status,priority:'normal',authority:'',forwardingReference:'',photos:[],uploadState:'complete',
  publicWarning:['reviewed','forwarded'].includes(status),createdBy:user.uid
});
console.log('ERA emulator browser fixture ready.');
