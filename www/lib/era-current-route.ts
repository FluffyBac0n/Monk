'use client';
import {collection,doc,getDoc,getDocs,orderBy,query} from 'firebase/firestore';
import {db} from './firebase';
import {eraCall,type RevisionDetail,type RevisionPayload} from './era';
import {decodeEditableRouteChunks} from './route-geometry';

export async function loadCurrentEraRoute(trailId:string) {
  const root=await getDoc(doc(db,'trails',trailId));
  if (!root.exists()) throw new Error('Trail unavailable.');
  const releaseId=(root.data().publishedReleaseId as string) || null;
  const prefix=releaseId?`trails/${trailId}/releases/${releaseId}`:`trails/${trailId}`;
  const release=releaseId?await getDoc(doc(db,prefix)):root;
  if (release.data()?.revisionId) {
    const detail=await eraCall<RevisionDetail>('getEraRevision',{trailId,revisionId:release.data()!.revisionId});
    return {payload:detail.payload,detail,releaseId};
  }
  const metadata=await getDoc(doc(db,`${prefix}/routeMetadata/main`));
  const body:RevisionPayload={segments:[],source:release.data()?.source || '',attribution:release.data()?.attribution || '',elevationSource:release.data()?.elevationSource || '',stageDecisions:{},relatedRoutesReviewed:false,changesReviewed:false};
  if (metadata.exists()) {
    const chunks=await getDocs(query(collection(db,`${prefix}/routeChunks`),orderBy('chunkIndex')));
    if (metadata.data().chunkCount!=null && chunks.size!==Number(metadata.data().chunkCount)) throw new Error('The trail download is incomplete. Try again.');
    const coordinates=decodeEditableRouteChunks(metadata.data(),chunks.docs.map(chunk=>chunk.data()));
    body.segments=[{kind:'main',coordinates}];
    body.source ||= metadata.data().source || `Current trail: ${root.data().name || trailId}`;
    body.attribution ||= metadata.data().attribution || '';
    body.elevationSource ||= metadata.data().elevationSource || (coordinates.every(point=>point.length===3)?'Current trail data':'');
  }
  return {payload:body,detail:null,releaseId};
}
