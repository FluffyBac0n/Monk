'use client';
import {httpsCallable} from 'firebase/functions';
import {collection, onSnapshot, orderBy, query, limit, where, type Timestamp} from 'firebase/firestore';
import {db,reportFunctions} from './firebase';
export const roleLabels: Record<string,string> = {organisation_admin:'Organisation administrator',editor:'Trail editor',verifier:'Trail verifier',incident_manager:'Incident manager',viewer:'Viewer / auditor'};
export type EraTrail = {id:string;name:string;roles:string[];publishedReleaseId:string|null};
export type EraAccess = {legacyMembers:{id:string;email:string;trailIds:string[]}[];admin:boolean;organisation:{id:string;name:string;trailIds:string[];active:boolean}|null;trails:EraTrail[];organisations:{id:string;name:string;trailIds:string[];active:boolean}[];members:{id:string;email:string;organisationId:string;trailRoles:Record<string,string[]>}[]};
export type Segment = {kind:'main'|'alternative';coordinates:number[][]};
export type StageDecision = {confirmed?:boolean;offRoute?:boolean;pointIndex?:number;location?:{latitude:number;longitude:number}};
export type RevisionPayload = {segments:Segment[];source:string;attribution:string;elevationSource:string;stageDecisions:Record<string,StageDecision>;relatedDecisions?:Record<string,{excluded?:boolean;startPointIndex?:number;endPointIndex?:number}>;relatedRoutesReviewed:boolean;changesReviewed:boolean};
export type Revision = {id:string;state:string;contributors:string[];createdAt?:Timestamp;updatedAt?:Timestamp;pointCount:number;totalDistanceKm:number;source:string;attribution:string;errors:string[];warnings:string[];note?:string;baseReleaseId:string|null};
export type StageLink = {stageId:string;name:string;pointIndex?:number;coordinates?:number[];location:{latitude:number;longitude:number}|null;accumulatedDistanceKm?:number;distanceFromPathKm?:number;problems:string[]};
export type RevisionDetail = {payload:RevisionPayload;validation:{errors:string[];warnings:string[];stageLinks:StageLink[];pointCount:number;totalDistanceKm:number};relatedRoutes:{excursions:{id:string;name:string}[];detours:{id:string;name:string}[]}};
export type EraEvent = {id:string;action:string;actorId:string;actorEmail:string;createdAt?:Timestamp;recordId:string;note?:string};
export type Release = {id:string;source:string;attribution:string;publishedAt?:Timestamp;publishedBy:string;approvedBy:string;totalDistanceKm:number;pointCount:number};
export async function eraCall<T=Record<string,unknown>>(name:string,data:unknown={}) {return (await httpsCallable<unknown,T>(reportFunctions,name,{timeout:120000})(data)).data;}
export function watchRevisions(trailId:string,receive:(v:Revision[])=>void,fail:(e:Error)=>void) {
  return onSnapshot(query(collection(db,'eraWorkspaces',trailId,'revisions'),orderBy('createdAt','desc'),limit(100)),s=>receive(s.docs.map(d=>({id:d.id,...d.data()}) as Revision)),fail);
}
export function watchEraAudit(trailId:string,count:number,receive:(v:EraEvent[])=>void,fail:(e:Error)=>void) {
  return onSnapshot(query(collection(db,'eraAudit'),where('trailId','==',trailId),orderBy('createdAt','desc'),limit(count)),s=>receive(s.docs.map(d=>({id:d.id,...d.data()}) as EraEvent)),fail);
}
export function watchReleases(trailId:string,receive:(v:Release[])=>void,fail:(e:Error)=>void) {
  return onSnapshot(query(collection(db,'trails',trailId,'releases'),where('published','==',true),orderBy('publishedAt','desc')),s=>receive(s.docs.map(d=>({id:d.id,...d.data()}) as Release)),fail);
}
