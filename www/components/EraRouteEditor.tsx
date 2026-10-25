'use client';
import {useEffect,useMemo,useRef,useState} from 'react';
import type {User} from 'firebase/auth';
import {doc,getDoc,onSnapshot} from 'firebase/firestore';
import {db} from '@/lib/firebase';
import {EraRouteMap} from './EraRouteMap';
import {ReportSelect} from './ReportSelect';
import {EraRouteReview} from './EraRouteReview';
import {EraRouteHistory} from './EraRouteHistory';
import {loadCurrentEraRoute} from '@/lib/era-current-route';
import {parseRouteFile,routeSummary,validateRouteSegments} from '@/lib/era-route-file';
import {eraCall,watchRevisions,type EraTrail,type Revision,type RevisionPayload,type RevisionDetail} from '@/lib/era';
const empty:RevisionPayload={segments:[],source:'',attribution:'',elevationSource:'',stageDecisions:{},relatedRoutesReviewed:false,changesReviewed:false};
type Snapshot={payload:RevisionPayload;raw:string|null};
export function EraRouteEditor({trail,user,onPublished}:{trail:EraTrail;user:User;onPublished:()=>Promise<void>}) {
  const [revisions,setRevisions]=useState<Revision[]>([]),[selected,setSelected]=useState('current'),[payload,setPayload]=useState<RevisionPayload>(empty),[detail,setDetail]=useState<RevisionDetail|null>(null);
  const [dirty,setDirty]=useState(false),[busy,setBusy]=useState(true),[loaded,setLoaded]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState(''),[raw,setRaw]=useState<string|null>(null);
  const [editing,setEditing]=useState(false),[adding,setAdding]=useState(false),[segment,setSegment]=useState(0),[point,setPoint]=useState(0);
  const [fitVersion,setFitVersion]=useState(0);
  const [undo,setUndo]=useState<Snapshot[]>([]),[redo,setRedo]=useState<Snapshot[]>([]);
  const [baseHead,setBaseHead]=useState<string|null>(null),[baseRelease,setBaseRelease]=useState<string|null>(trail.publishedReleaseId),[activeRelease,setActiveRelease]=useState<string|null>(trail.publishedReleaseId);
  const fileInput=useRef<HTMLInputElement>(null),request=useRef(0),initialised=useRef(false),revisionRows=useRef<Revision[]>([]);
  const canEdit=trail.roles.includes('editor'),revision=revisions.find(row=>row.id===selected),latest=revisions[0]?.id || null;
  const canVerify=trail.roles.includes('verifier') && !!revision && !revision.contributors.includes(user.uid);
  const stale=loaded && (baseHead!==latest || baseRelease!==activeRelease);
  const coordinates=payload.segments[segment]?.coordinates || [],selectedPoint=coordinates[point];
  const stats=useMemo(()=>routeSummary(payload.segments),[payload.segments]);

  async function load(selection:string,head=revisionRows.current[0]?.id || null) {
    const version=++request.current;
    setBusy(true);setError('');setMessage('');
    try {
      const result=selection==='current'?await loadCurrentEraRoute(trail.id):null;
      const next=result?.detail || (selection!=='current'?await eraCall<RevisionDetail>('getEraRevision',{trailId:trail.id,revisionId:selection}):null);
      if(version!==request.current)return;
      const savedRow=revisionRows.current.find(row=>row.id===selection);
      const release=result?result.releaseId:savedRow?savedRow.baseReleaseId:activeRelease;
      setPayload(result?.payload || next!.payload);setDetail(next);setSelected(selection);setBaseHead(head);setBaseRelease(release);
      setDirty(false);setRaw(null);setUndo([]);setRedo([]);setSegment(0);setPoint(0);setEditing(false);setAdding(false);setLoaded(true);setFitVersion(value=>value+1);
    } catch(e) {if(version===request.current)setError(e instanceof Error?e.message:'Could not load this trail.');}
    finally {if(version===request.current)setBusy(false);}
  }
  useEffect(()=>{
    initialised.current=false;
    const stop=watchRevisions(trail.id,rows=>{revisionRows.current=rows;setRevisions(rows);if(!initialised.current){initialised.current=true;void load('current',rows[0]?.id || null);}},e=>{setError(e.message);setBusy(false);});
    const current=onSnapshot(doc(db,'trails',trail.id),snapshot=>setActiveRelease(snapshot.data()?.publishedReleaseId || null),e=>setError(e.message));
    return()=>{request.current++;stop();current();};
  },[trail.id]);
  useEffect(()=>{const warn=(event:BeforeUnloadEvent)=>{if(dirty){event.preventDefault();event.returnValue='';}};window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);},[dirty]);
  function choose(selection:string){if(dirty && !window.confirm('Discard unsaved trail changes?'))return;void load(selection);}
  function edit(next:RevisionPayload,nextRaw=raw) {
    if(next.segments!==payload.segments)next={...next,stageDecisions:Object.fromEntries(Object.entries(next.stageDecisions).map(([id,value])=>[id,{location:value.location,offRoute:value.offRoute,confirmed:false}])),relatedDecisions:Object.fromEntries(Object.entries(next.relatedDecisions || {}).map(([id,value])=>[id,{excluded:value.excluded}])),relatedRoutesReviewed:false,changesReviewed:false};
    setUndo(rows=>[...rows.slice(-19),{payload,raw}]);setRedo([]);setPayload(next);setRaw(nextRaw);setDirty(true);setMessage('');setError('');
  }
  function changePoint(next:number[]) {
    if(!selectedPoint || busy || !canEdit)return;
    if(!next.every(Number.isFinite) || Math.abs(next[0])>180 || Math.abs(next[1])>85 || (next.length===3 && (next[2]<-500 || next[2]>9000))){setError('Enter valid coordinates and an elevation between −500 and 9,000 m.');return;}
    edit({...payload,segments:payload.segments.map((section,index)=>index===segment?{...section,coordinates:section.coordinates.map((coordinate,number)=>number===point?next:coordinate)}:section)});
  }
  function restore(snapshot:Snapshot) {
    setPayload(snapshot.payload);setRaw(snapshot.raw);setDirty(true);setMessage('');setError('');setSegment(0);setPoint(0);setAdding(false);
  }
  async function upload(file:File) {
    if(dirty && !window.confirm('Replace your unsaved route with this file?'))return;
    setBusy(true);setError('');
    try {
      if(file.size>8*1024*1024)throw new Error('Choose a GPX file smaller than 8 MB.');
      const imported=parseRouteFile(await file.text(),file.name);
      edit({...empty,segments:imported.segments,source:imported.source,attribution:imported.attribution,elevationSource:imported.elevationSource},imported.geojson);
      if(!loaded){setBaseHead(latest);setBaseRelease(activeRelease);}
      setSegment(0);setPoint(0);setEditing(false);setAdding(false);setLoaded(true);setFitVersion(value=>value+1);setMessage(`${file.name} loaded. Save changes to keep it.`);
    } catch(e){setError(e instanceof Error?e.message:'Could not read this route file.');}
    finally{setBusy(false);}
  }
  async function save() {
    setBusy(true);setError('');setMessage('');
    try {
      validateRouteSegments(payload.segments);
      if(stale)throw new Error('This trail has newer changes. Open the latest saved changes before saving.');
      const current=await getDoc(doc(db,'trails',trail.id));
      if((current.data()?.publishedReleaseId || null)!==baseRelease)throw new Error('The published trail changed. Open the current trail before saving.');
      const result=await eraCall<{revisionId:string}>('saveEraRevision',{trailId:trail.id,expectedRevisionId:baseHead,...payload,...(raw?{originalGeoJSON:raw}:{})});
      await load(result.revisionId,result.revisionId);setMessage('Changes saved as a draft.');
    } catch(e){setError(e instanceof Error?e.message:'Could not save changes.');}
    finally{setBusy(false);}
  }
  async function transition(action:string,note:string) {
    setBusy(true);setError('');setMessage('');
    try {
      await eraCall('transitionEraRevision',{trailId:trail.id,revisionId:selected,action,note});
      if(action==='publish'){await load('current');await onPublished();}
      setMessage(action==='publish'?'Trail published.':action==='approve'?'Changes approved.':action==='submit'?'Changes sent for review.':'Changes requested.');
    } catch(e){setError(e instanceof Error?e.message:'Could not complete this action.');}
    finally{setBusy(false);}
  }
  const viewOptions=[{value:'current',label:'Current trail'},...((latest && revisions[0].state!=='published')?[{value:latest,label:'Latest saved changes'}]:[]),...(selected!=='current' && selected!==latest?[{value:selected,label:'Earlier saved changes'}]:[]),...(selected===latest && revision?.state==='published'?[{value:selected,label:'Published changes'}]:[])];
  return <section className="era-route-editor era-simple-editor" data-era-dirty={dirty?'true':'false'}>
    <div className="era-editor-toolbar">
      <div className="era-editor-view">{viewOptions.length>1?<ReportSelect label="Viewing" value={selected} options={viewOptions} disabled={busy} onChange={choose}/>:<strong>Current trail</strong>}<span className="era-editor-stats">{loaded?`${stats.distanceKm.toFixed(1)} km · ${stats.pointCount.toLocaleString()} points${dirty?' · Unsaved changes':''}`:'Loading trail…'}</span></div>
      {canEdit && <div className="era-editor-tools"><input ref={fileInput} type="file" hidden style={{display:'none'}} tabIndex={-1} aria-label="GPX route file" accept=".gpx,.geojson,.json,application/gpx+xml,application/geo+json,application/json" disabled={busy} onChange={event=>{const file=event.target.files?.[0];if(file)void upload(file);event.target.value='';}}/><button type="button" className="button button-secondary" disabled={busy} onClick={()=>fileInput.current?.click()}>Upload GPX</button><button type="button" className={`button ${editing?'button-primary':'button-secondary'}`} disabled={busy || !payload.segments.length} aria-pressed={editing} onClick={()=>{setEditing(value=>!value);setAdding(false);}}>{editing?'Done editing':'Edit points'}</button><button type="button" className="button button-primary" disabled={busy || !dirty || stale || !payload.segments.length} onClick={()=>void save()}>{busy && dirty?'Saving…':'Save changes'}</button></div>}
    </div>
    {error && <div className="notice error" role="alert"><p>{error}</p>{!loaded && <button type="button" className="button button-secondary" disabled={busy} onClick={()=>void load('current')}>Retry</button>}</div>}
    {message && <p className="notice" role="status">{message}</p>}
    {stale && !busy && <p className="notice">Newer trail data is available. <button type="button" className="text-button" disabled={busy} onClick={()=>choose(baseRelease!==activeRelease?'current':latest || 'current')}>Load latest</button></p>}
    {editing && <div className="era-point-toolbar"><p>{adding?'Click the map to insert a point after the selected point.':'Select a point on the trail, then drag it to move it.'}</p><div className="era-editor-tools"><button type="button" className="button button-secondary" disabled={busy || !undo.length} onClick={()=>{setRedo(rows=>[{payload,raw},...rows]);restore(undo.at(-1)!);setUndo(rows=>rows.slice(0,-1));}}>Undo</button><button type="button" className="button button-secondary" disabled={busy || !redo.length} onClick={()=>{setUndo(rows=>[...rows,{payload,raw}]);restore(redo[0]);setRedo(rows=>rows.slice(1));}}>Redo</button><button type="button" className={`button ${adding?'button-primary':'button-secondary'}`} disabled={busy || !selectedPoint} aria-pressed={adding} onClick={()=>setAdding(value=>!value)}>Add point</button></div></div>}
    <EraRouteMap fitKey={fitVersion} trailId={trail.id} segments={payload.segments} links={[]} segmentIndex={segment} pointIndex={point} editable={editing && adding && !busy} editing={editing} draggable={editing && !adding && !busy && canEdit} current={selected==='current' && !dirty} onMove={position=>changePoint(selectedPoint?.length===3?[...position,selectedPoint[2]]:position)} onSelect={(section,index)=>{setSegment(section);setPoint(index);}} onPoint={position=>{if(!editing || !adding || busy || !canEdit || !selectedPoint)return;const next=[...coordinates];next.splice(point+1,0,position);edit({...payload,segments:payload.segments.map((section,index)=>index===segment?{...section,coordinates:next}:section)});setPoint(point+1);setAdding(false);}}/>
    {loaded && !payload.segments.length && <p className="notice">No trail geometry yet.{canEdit?' Upload a GPX file to get started.':''}</p>}
    {editing && selectedPoint && <section className="form-panel era-point-editor" aria-label="Selected point"><fieldset disabled={busy || !canEdit}><div className="form-grid">
      {payload.segments.length>1 && <ReportSelect label="Section" value={String(segment)} options={payload.segments.map((section,index)=>({value:String(index),label:`${index+1} · ${section.coordinates.length.toLocaleString()} points`}))} onChange={value=>{setSegment(Number(value));setPoint(0);}}/>}
      <label>Point<input type="number" min={1} max={coordinates.length} value={point+1} onChange={event=>{if(event.target.value)setPoint(Math.max(0,Math.min(coordinates.length-1,Math.trunc(Number(event.target.value)-1))));}}/></label>
      {['Longitude','Latitude','Elevation (m)'].map((label,index)=><label key={label}>{label}<input type="number" step="any" value={selectedPoint[index] ?? ''} onChange={event=>{if(index<2 && !event.target.value)return;const next=[...selectedPoint];if(index===2 && !event.target.value)next.splice(2);else next[index]=Number(event.target.value);changePoint(next);}}/></label>)}
    </div><div className="era-editor-tools"><button type="button" className="text-button" disabled={coordinates.length<=2} onClick={()=>{edit({...payload,segments:payload.segments.map((section,index)=>index===segment?{...section,coordinates:coordinates.filter((_,number)=>number!==point)}:section)});setPoint(Math.max(0,point-1));}}>Delete point</button></div></fieldset></section>}
    <EraRouteReview payload={payload} detail={detail} revision={revision} canEdit={canEdit && !busy} canVerify={canVerify} busy={busy || stale} dirty={dirty} latest={latest} userId={user.uid} edit={edit} transition={transition}/>
    <EraRouteHistory trailId={trail.id} revisions={revisions} activeReleaseId={activeRelease} canRestore={trail.roles.includes('verifier')} busy={busy || dirty} onLoad={choose} onRestore={async()=>{await load('current');await onPublished();}}/>
  </section>;
}
