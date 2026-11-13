'use client';
import {useEffect,useRef,useState} from 'react';
import {useIncidentDraft} from './IncidentDrafts';
import {getMetadata,ref,uploadBytes} from 'firebase/storage';
import {auth,reportStorage} from '@/lib/firebase';
import {eraCall} from '@/lib/era';
import {reportCategories} from '@/lib/trail-reports';
import {ReportSelect} from './ReportSelect';
import {ReportProblemIcon} from './ReportProblemIcon';
import {EraRouteMap} from './EraRouteMap';
type Photo={id:string;bytes:Uint8Array<ArrayBuffer>;sha256Hash:string;byteLength:number};
type PendingIncident={reportId:string;photos:Photo[];body:Record<string,unknown>;created?:boolean};
type IncidentDraft={category:string;passability:string;priority:string;description:string;latitude:string;longitude:string;stageId:string;date:string;files:File[];pending:PendingIncident|null};
async function preparePhotos(files:File[]):Promise<Photo[]> {
  return Promise.all(files.map(async(file,i)=>{
    if(file.size>20*1024*1024)throw new Error('Each source photo must be smaller than 20 MB.');
    const bitmap=await createImageBitmap(file);
    if(bitmap.width*bitmap.height>24_000_000){bitmap.close();throw new Error('Use photos smaller than 24 megapixels.');}
    const canvas=document.createElement('canvas'),scale=Math.min(1,1800/Math.max(bitmap.width,bitmap.height));canvas.width=Math.round(bitmap.width*scale);canvas.height=Math.round(bitmap.height*scale);
    canvas.getContext('2d')!.drawImage(bitmap,0,0,canvas.width,canvas.height);bitmap.close();
    const blob=await new Promise<Blob>((resolve,reject)=>canvas.toBlob(b=>b?resolve(b):reject(new Error('Photo could not be read.')),'image/jpeg',0.8));
    if(blob.size>=2*1024*1024)throw new Error('A photo is too large after resizing. Choose a smaller image.');
    const bytes=new Uint8Array(await blob.arrayBuffer()),hash=await crypto.subtle.digest('SHA-256',bytes);
    return {id:`photo_${i}`,bytes,sha256Hash:Array.from(new Uint8Array(hash),b=>b.toString(16).padStart(2,'0')).join(''),byteLength:bytes.byteLength};
  }));
}
export function EraIncidentForm({trailId,open,onClose}:{trailId:string;open:boolean;onClose:()=>void}) {
  const draft=useIncidentDraft<IncidentDraft>(`new:${trailId}`);
  const [initial]=useState(()=>draft.read());
  const [category,setCategory]=useState(initial?.category || 'signpost'),[passability,setPassability]=useState(initial?.passability || 'unsure'),[priority,setPriority]=useState(initial?.priority || 'normal');
  const [description,setDescription]=useState(initial?.description || ''),[latitude,setLatitude]=useState(initial?.latitude || ''),[longitude,setLongitude]=useState(initial?.longitude || ''),[stageId,setStageId]=useState(initial?.stageId || ''),[date,setDate]=useState(()=>{if(initial?.date)return initial.date;const now=new Date();return new Date(now.getTime()-now.getTimezoneOffset()*60000).toISOString().slice(0,16);});
  const [files,setFiles]=useState<File[]>(initial?.files || []),[mapOpen,setMapOpen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
  const pending=useRef<PendingIncident|null>(initial?.pending || null);
  const draftValue={category,passability,priority,description,latitude,longitude,stageId,date,files,pending:pending.current};
  const latest=useRef(draftValue);latest.current=draftValue;
  useEffect(()=>{
    if(description || latitude || longitude || stageId || files.length || pending.current || category!=='signpost' || passability!=='unsure' || priority!=='normal')draft.save({...draftValue,pending:pending.current});
    else draft.clear();
  },[draft,category,passability,priority,description,latitude,longitude,stageId,date,files,busy]);
  async function submit(){
    setBusy(true);setError('');setMessage('');
    try {
      if(!pending.current){const photos=await preparePhotos(files);pending.current={reportId:crypto.randomUUID(),photos,body:{trailId,category,passability,priority,description,latitude:Number(latitude),longitude:Number(longitude),stageId:stageId || null,observedAtMs:new Date(date).getTime()}};}
      draft.save({...latest.current,pending:pending.current});
      const {reportId,photos,body}=pending.current;
      await eraCall('createEraIncident',{...body,reportId,photoIds:photos.map(p=>p.id)});
      pending.current.created=true;
      const receipt=await eraCall<{received:boolean}>('trailReportReceipt',{reportId});
      if(!receipt.received)for(const p of photos){
        const destination=ref(reportStorage,`trail-report-uploads/${auth.currentUser!.uid}/${reportId}/${p.id}/photo.jpg`);
        let uploaded=false;
        try {const m=await getMetadata(destination);uploaded=m.size===p.byteLength && m.customMetadata?.sha256Hash===p.sha256Hash;}catch(e){if((e as {code?:string}).code!=='storage/object-not-found')throw e;}
        if(!uploaded)await uploadBytes(destination,p.bytes,{contentType:'image/jpeg',customMetadata:{sha256Hash:p.sha256Hash}});
      }
      if(photos.length && !receipt.received)await eraCall('finalizeTrailReport',{reportId,photoChecksums:photos.map(({id,sha256Hash,byteLength})=>({id,sha256Hash,byteLength}))});
      pending.current=null;draft.clear();setDescription('');setLatitude('');setLongitude('');setStageId('');setCategory('signpost');setPassability('unsure');setPriority('normal');setFiles([]);setMapOpen(false);onClose();setMessage('Incident created.');
    }catch(e){if(!pending.current?.created)pending.current=null;setError(e instanceof Error?e.message:'Could not create incident. Retry to finish the same submission.');}
    finally{if(pending.current)draft.save({...latest.current,pending:pending.current});setBusy(false);}
  }
  const pin=latitude!=='' && longitude!=='' && Math.abs(Number(latitude))<=85 && Math.abs(Number(longitude))<=180?[Number(longitude),Number(latitude)]:undefined;
  return <>{message && <p className="notice" role="status">{message}</p>}{open && <section className="form-panel era-incident-create"><h2>New incident</h2><form id="era-incident-form" onSubmit={e=>{e.preventDefault();void submit();}}><fieldset disabled={busy || !!pending.current}><div className="form-grid">
    <ReportSelect label="Problem" value={category} onChange={setCategory} options={Object.entries(reportCategories).map(([value,label])=>({value,label,indicator:<ReportProblemIcon category={value}/>}))}/><ReportSelect label="Trail access" value={passability} onChange={setPassability} options={['passable','difficult','blocked','unsure'].map(value=>({value,label:value}))}/><ReportSelect label="Priority" value={priority} onChange={setPriority} options={['normal','high','urgent'].map(value=>({value,label:value}))}/>
    <label>Description<textarea required maxLength={500} value={description} onChange={e=>setDescription(e.target.value)}/></label><label>Latitude<input required type="number" step="any" min={-85} max={85} value={latitude} onChange={e=>setLatitude(e.target.value)}/></label><label>Longitude<input required type="number" step="any" min={-180} max={180} value={longitude} onChange={e=>setLongitude(e.target.value)}/></label><label>Observed<input required type="datetime-local" value={date} onChange={e=>setDate(e.target.value)}/></label><label>Stage ID (optional)<input value={stageId} onChange={e=>setStageId(e.target.value)}/></label><label>Photos (up to three)<span className="era-photo-input"><span className="button button-secondary">Choose photos</span><input className="sr-only" type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={e=>{const next=Array.from(e.target.files || []);if(next.length>3){setError('Choose up to three photos.');e.target.value='';setFiles([]);}else if(next.length){setFiles(next);setError('');}}}/></span>{files.length>0 && <span className="report-selected-files">{files.map(file=>file.name).join(', ')}</span>}</label>
    <div className="era-incident-location"><button type="button" className="button button-secondary" aria-expanded={mapOpen} aria-controls="era-incident-location-map" onClick={()=>setMapOpen(v=>!v)}><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/></svg>{mapOpen?'Hide location map':'Choose location'}</button></div>
    </div></fieldset>
    {mapOpen && <div id="era-incident-location-map"><EraRouteMap trailId={trailId} segments={[]} links={[]} segmentIndex={0} pointIndex={0} pin={pin} editable={!busy && !pending.current} onSelect={()=>{}} onPoint={p=>{setLongitude(p[0].toFixed(6));setLatitude(p[1].toFixed(6));}}/></div>}
    {error && <p className="notice error" role="alert">{error}</p>}<div className="era-actions era-incident-submit"><button className="button button-primary" disabled={busy}>{busy?'Saving incident…':pending.current?'Retry incident upload':'Create incident'}</button></div>
  </form></section>}</>;
}
