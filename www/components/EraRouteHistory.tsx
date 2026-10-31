import {useEffect,useState} from 'react';
import {eraCall,watchReleases,revisionStateLabels,type Release,type Revision} from '@/lib/era';

export function EraRouteHistory({trailId,revisions,activeReleaseId,canRestore,busy,onLoad,onRestore}:{trailId:string;revisions:Revision[];activeReleaseId:string|null;canRestore:boolean;busy:boolean;onLoad:(id:string)=>void;onRestore:()=>Promise<void>}) {
  const [open,setOpen]=useState(false);
  const [releases,setReleases]=useState<Release[]>([]),[error,setError]=useState(''),[reason,setReason]=useState(''),[restoring,setRestoring]=useState(false);
  useEffect(()=>{if(open)return watchReleases(trailId,setReleases,e=>setError(e.message));},[trailId,open]);
  return <details className="era-editor-details" onToggle={event=>setOpen(event.currentTarget.open)}><summary>History</summary>
    {error && <p className="notice error" role="alert">{error}</p>}
    <ul className="report-members">{revisions.map(revision=><li key={revision.id}><div><strong>{revision.createdAt?.toDate().toLocaleString() || 'Saved changes'}</strong><p>{revision.state==='approved' && !revision.verification?'Earlier approval · verification required':revisionStateLabels[revision.state] || revision.state} · {revision.pointCount.toLocaleString()} points</p></div><button type="button" className="button button-secondary" disabled={busy || restoring} onClick={()=>onLoad(revision.id)}>Open</button></li>)}</ul>
    {!revisions.length && <p>No saved changes yet.</p>}
    {releases.length>0 && <><h3>Published trail history</h3>{canRestore && releases.some(release=>release.id!==activeReleaseId) && <label>Reason for restoring<input value={reason} maxLength={1500} disabled={busy || restoring} onChange={e=>setReason(e.target.value)}/></label>}
      <ul className="report-members">{releases.map(release=><li key={release.id}><div><strong>{release.id===activeReleaseId?'Current trail':release.publishedAt?.toDate().toLocaleString() || 'Published trail'}</strong><p>{release.totalDistanceKm.toFixed(1)} km · {release.pointCount.toLocaleString()} points</p><small>{release.verification?.status==='verified'?`Verified by ${release.verification.organisationName} · ${release.verification.verifiedAt?.toDate().toLocaleDateString()}`:'No organisation verification recorded'}</small></div>{canRestore && release.id!==activeReleaseId && <button type="button" className="button button-secondary" disabled={busy || restoring || !reason.trim()} onClick={async()=>{setRestoring(true);setError('');try {await eraCall('rollbackEraRelease',{trailId,releaseId:release.id,expectedReleaseId:activeReleaseId,note:reason});setReason('');await onRestore();} catch(e){setError(e instanceof Error?e.message:'Could not restore trail.');} finally{setRestoring(false);}}}>Restore</button>}</li>)}</ul>
    </>}
  </details>;
}
