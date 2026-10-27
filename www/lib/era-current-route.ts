'use client';
import {collection,doc,getDoc,getDocs,orderBy,query} from 'firebase/firestore';
import {auth,db} from './firebase';
import {eraCall,type RevisionPayload} from './era';
import {decodeEditableRouteChunks} from './route-geometry';

type CurrentRoute={payload:RevisionPayload;releaseId:string|null};
const pending=new Map<string,Promise<CurrentRoute>>();
const snapshots=new Map<string,CurrentRoute>();
let generation=0;
export function clearCurrentEraRoutes(){generation++;pending.clear();snapshots.clear();}

/** Session-only cache, keyed by account and the current immutable release/geometry version. */
export function loadCurrentEraRoute(trailId:string):Promise<CurrentRoute> {
  const epoch=generation,account=auth.currentUser?.uid || '',key=`${account}:${trailId}`;
  const existing=pending.get(key);if(existing)return existing;
  const load=(async()=>{
    const root=await getDoc(doc(db,'trails',trailId));
    if(!root.exists())throw new Error('Trail unavailable.');
    const releaseId=(root.data().publishedReleaseId as string) || null;
    const prefix=releaseId?`trails/${trailId}/releases/${releaseId}`:`trails/${trailId}`;
    if(releaseId){
      const cached=snapshots.get(`${key}:${releaseId}`);if(cached)return cached;
      const release=await getDoc(doc(db,prefix));
      if(release.data()?.revisionId){
        const {payload}=await eraCall<{payload:RevisionPayload}>('getEraRevision',{trailId,revisionId:release.data()!.revisionId,payloadOnly:true});
        const value={payload,releaseId};if(generation===epoch && auth.currentUser?.uid===account)snapshots.set(`${key}:${releaseId}`,value);return value;
      }
    }
    const metadata=await getDoc(doc(db,`${prefix}/routeMetadata/main`));
    const data=metadata.data();
    const revision=JSON.stringify([releaseId,data?.version,data?.updatedAt?.toMillis?.(),data?.pointCount,data?.chunkCount]);
    const cached=snapshots.get(`${key}:${revision}`);if(cached)return cached;
    const payload:RevisionPayload={segments:[],source:root.data().source || '',attribution:root.data().attribution || '',elevationSource:root.data().elevationSource || '',stageDecisions:{},relatedRoutesReviewed:false,changesReviewed:false};
    if(data){
      const chunks=await getDocs(query(collection(db,`${prefix}/routeChunks`),orderBy('chunkIndex')));
      if(data.chunkCount!=null && chunks.size!==Number(data.chunkCount))throw new Error('The trail download is incomplete. Try again.');
      const coordinates=decodeEditableRouteChunks(data,chunks.docs.map(chunk=>chunk.data()));
      payload.segments=[{kind:'main',coordinates}];
      payload.source ||= data.source || `Current trail: ${root.data().name || trailId}`;
      payload.attribution ||= data.attribution || '';
      payload.elevationSource ||= data.elevationSource || (coordinates.every(point=>point.length===3)?'Current trail data':'');
    }
    const value={payload,releaseId};if(generation===epoch && auth.currentUser?.uid===account)snapshots.set(`${key}:${revision}`,value);return value;
  })();
  pending.set(key,load);
  void load.finally(()=>{if(pending.get(key)===load)pending.delete(key);}).catch(()=>{});
  return load;
}
