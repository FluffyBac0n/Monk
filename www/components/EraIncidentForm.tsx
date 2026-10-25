'use client';
import {useRef,useState} from 'react';
import {getMetadata,ref,uploadBytes} from 'firebase/storage';
import {auth,reportStorage} from '@/lib/firebase';
import {eraCall} from '@/lib/era';
import {reportCategories} from '@/lib/trail-reports';
import {ReportSelect} from './ReportSelect';
import {EraRouteMap} from './EraRouteMap';
type Photo={id:string;bytes:Uint8Array<ArrayBuffer>;sha256Hash:string;byteLength:number};
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
export function EraIncidentForm({trailId}:{trailId:string}) {
  const [open,setOpen]=useState(false),[category,setCategory]=useState('signpost'),[passability,setPassability]=useState('unsure'),[priority,setPriority]=useState('normal');
  const [description,setDescription]=useState(''),[latitude,setLatitude]=useState(''),[longitude,setLongitude]=useState(''),[stageId,setStageId]=useState(''),[date,setDate]=useState(()=>{const now=new Date();return new Date(now.getTime()-now.getTimezoneOffset()*60000).toISOString().slice(0,16);});
  const [files,setFiles]=useState<File[]>([]),[mapOpen,setMapOpen]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
  const pending=useRef<{reportId:string;photos:Photo[];body:Record<string,unknown>;created?:boolean}|null>(null);
  async function submit(){
    setBusy(true);setError('');setMessage('');
    try {
      if(!pending.current){const photos=await preparePhotos(files);pending.current={reportId:crypto.randomUUID(),photos,body:{trailId,category,passability,priority,description,latitude:Number(latitude),longitude:Number(longitude),stageId:stageId || null,observedAtMs:new Date(date).getTime()}};}
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
      pending.current=null;setDescription('');setFiles([]);setOpen(false);setMessage('Organisation incident created. Review it to publish a public warning.');
    }catch(e){if(!pending.current?.created)pending.current=null;setError(e instanceof Error?e.message:'Could not create incident. Retry to finish the same submission.');}
    finally{setBusy(false);}
  }
  const pin=latitude!=='' && longitude!=='' && Math.abs(Number(latitude))<=85 && Math.abs(Number(longitude))<=180?[Number(longitude),Number(latitude)]:undefined;
  return <section className="form-panel"><button className="button button-secondary" aria-expanded={open} onClick={()=>setOpen(o=>!o)}>{open?'Close incident form':'Create incident'}</button>{message && <p className="notice" role="status">{message}</p>}{open && <form onSubmit={e=>{e.preventDefault();void submit();}}><fieldset disabled={busy || !!pending.current}><div className="form-grid">
    <ReportSelect label="Problem" value={category} onChange={setCategory} options={Object.entries(reportCategories).map(([value,label])=>({value,label}))}/><ReportSelect label="Trail access" value={passability} onChange={setPassability} options={['passable','difficult','blocked','unsure'].map(value=>({value,label:value}))}/><ReportSelect label="Priority" value={priority} onChange={setPriority} options={['normal','high','urgent'].map(value=>({value,label:value}))}/>
    <label>Description<textarea required maxLength={500} value={description} onChange={e=>setDescription(e.target.value)}/></label><label>Latitude<input required type="number" step="any" min={-85} max={85} value={latitude} onChange={e=>setLatitude(e.target.value)}/></label><label>Longitude<input required type="number" step="any" min={-180} max={180} value={longitude} onChange={e=>setLongitude(e.target.value)}/></label><label>Observed<input required type="datetime-local" value={date} onChange={e=>setDate(e.target.value)}/></label><label>Stage ID (optional)<input value={stageId} onChange={e=>setStageId(e.target.value)}/></label><label>Photos (up to three)<input type="file" accept="image/jpeg,image/png,image/webp" multiple onChange={e=>{const next=Array.from(e.target.files || []);if(next.length>3){setError('Choose up to three photos.');e.target.value='';setFiles([]);}else{setFiles(next);setError('');}}}/></label>
    </div><button type="button" className="button button-secondary" onClick={()=>setMapOpen(v=>!v)}>{mapOpen?'Hide location map':'Choose location on map'}</button></fieldset>
    {mapOpen && <EraRouteMap trailId={trailId} segments={[]} links={[]} segmentIndex={0} pointIndex={0} pin={pin} editable={!busy && !pending.current} onSelect={()=>{}} onPoint={p=>{setLongitude(p[0].toFixed(6));setLatitude(p[1].toFixed(6));}}/>}
    <div className="era-actions"><button className="button button-primary" disabled={busy}>{busy?'Saving incident…':pending.current?'Retry incident upload':'Create incident'}</button></div>{error && <p className="notice error" role="alert">{error}</p>}
  </form>}</section>;
}
