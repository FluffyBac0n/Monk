'use client';
import {useCallback,useEffect,useMemo,useState} from 'react';
import type {User} from 'firebase/auth';
import {doc,onSnapshot} from 'firebase/firestore';
import {db} from '@/lib/firebase';
import {useAuthState} from '@/lib/use-auth';
import {AuthPanel} from '@/components/AuthPanel';
import {AccountVerificationGate} from '@/components/AccountVerificationGate';
import {PortalHeader} from '@/components/PortalHeader';
import {ReportSelect} from '@/components/ReportSelect';
import {ReportWorkspace} from '@/components/IncidentWorkspace';
import {EraRouteEditor} from '@/components/EraRouteEditor';
import {EraAccessManager} from '@/components/EraAccessManager';
import {auditSearchText,matchesAuditSearch} from '@/lib/audit-search';
import {loadCurrentEraRoute,clearCurrentEraRoutes} from '@/lib/era-current-route';
import {eraCall,watchEraAudit,type EraAccess,type EraEvent} from '@/lib/era';

export default function EraPage() {
  const {user,loading}=useAuthState();
  if(loading) return <div className="loading-screen">Opening Trail Management…</div>;
  if(!user) return <main className="portal-page"><PortalHeader/><AuthPanel trailReports/></main>;
  if(!user.emailVerified) return <AccountVerificationGate user={user}/>;
  return <EraWorkspace key={user.uid} user={user}/>;
}
function EraWorkspace({user}:{user:User}) {
  const [access,setAccess]=useState<EraAccess|null>(null),[error,setError]=useState(''),[trailId,setTrailId]=useState(''),[tab,setTab]=useState('Incidents');
  const refresh=useCallback(async()=>{try {const next=await eraCall<EraAccess>('getEraAccess');setAccess(next);setTrailId(id=>next.trails.some(t=>t.id===id)?id:next.trails[0]?.id || '');setError('');}catch(e){setAccess(null);setError(e instanceof Error?e.message:'Could not load trail access.');}},[]);
  useEffect(()=>{
    let alive=true,version=0;
    const update=()=>{clearCurrentEraRoutes();const current=++version;setAccess(null);void eraCall<EraAccess>('getEraAccess').then(next=>{if(!alive || version!==current)return;setAccess(next);setTrailId(id=>next.trails.some(t=>t.id===id)?id:next.trails[0]?.id || '');setError('');},e=>{if(alive && version===current)setError(e.message || 'Could not load trail access.');});};
    const stops=['eraMembers','trailReportAccess','admins'].map(c=>onSnapshot(doc(db,c,user.uid),{includeMetadataChanges:true},s=>{if(!s.metadata.fromCache)update();},()=>{if(alive){setAccess(null);setError('Could not verify trail access.');}}));
    update();return ()=>{alive=false;stops.forEach(s=>s());};
  },[user.uid]);
  useEffect(()=>{
    if(!access?.organisation?.id)return;
    return onSnapshot(doc(db,'eraOrganisations',access.organisation.id),s=>{if(s.exists() && (s.data().active!==access.organisation?.active || JSON.stringify(s.data().trailIds)!==JSON.stringify(access.organisation?.trailIds)))void refresh();},()=>{setAccess(null);setError('Organisation access is unavailable.');});
  },[access?.organisation?.id,access?.organisation?.active,access?.organisation?.trailIds,refresh]);
  const trail=access?.trails.find(t=>t.id===trailId);
  useEffect(()=>{if(trail && trail.roles.some(role=>['editor','verifier','viewer'].includes(role)))void loadCurrentEraRoute(trail.id).catch(()=>{});},[trail?.id,trail?.publishedReleaseId]);
  const roles=trail?.roles || [];
  const incidentAccess=useMemo(()=>({admin:access?.admin || false,trails:trail?[{id:trail.id,name:trail.name}]:[]}),[access?.admin,trail]);
  const tabs=['Incidents','Trail Data','Audit Log',...((access?.admin || roles.includes('organisation_admin'))?['Access']:[])];
  return <main className="portal-page era-page"><PortalHeader user={user} canAccessAdmin={access?.admin}/><div className="dashboard-shell wide">
    <section className="dashboard-title"><div><h1 className="section-title">Trail Management</h1></div></section>
    {error && <div className="notice error" role="alert"><p>{error}</p><button className="button button-secondary" onClick={()=>void refresh()}>Try again</button></div>}
    {!access && !error && <p role="status">Checking your assigned trails…</p>}
    {access && !access.trails.length && <section className="access-card"><h2>No trails assigned yet.</h2><p>Ask your administrator to assign trail access to {user.email}.</p></section>}
    {access && <><div className="era-navigation">{access.trails.length>0 && <div className="era-trail-choice"><ReportSelect appearance="tab" label="Trail" value={trailId} onChange={id=>{if(document.querySelector('[data-era-dirty=true]') && !window.confirm('Discard unsaved changes?'))return;setTrailId(id);setTab('Incidents');}} options={access.trails.map(t=>({value:t.id,label:t.name}))}/></div>}
      <nav className="trail-switcher era-tabs" aria-label="Trail management"><ul className="trail-switcher-list" role="list">{tabs.map(t=><li key={t}><button type="button" className={`trail-switcher-item${tab===t?' active':''}`} aria-current={tab===t?'true':undefined} onClick={event=>{if(t!==tab && document.querySelector('[data-era-dirty=true]') && !window.confirm('Discard unsaved changes?'))return;setTab(t);event.currentTarget.scrollIntoView({block:'nearest',inline:'nearest'});}}><strong>{t}</strong></button></li>)}</ul></nav></div>
      {trail && <div key={trail.id}>
        {tab==='Incidents' && (roles.includes('incident_manager')?<div className="era-incidents"><ReportWorkspace key={trail.id} user={user} embeddedAccess={incidentAccess} initialTrailId={trail.id}/></div>:<p className="notice">Incident manager access is required to open private incidents.</p>)}
        {tab==='Trail Data' && <EraRouteEditor key={trail.id} trail={trail} user={user} onPublished={refresh}/>}
        {tab==='Audit Log' && <AuditLog trailId={trail.id}/>}
      </div>}
      {tab==='Access' && <EraAccessManager key={trailId} access={access} trailId={trailId} onChanged={refresh}/>}</>}
  </div></main>;
}
function AuditLog({trailId}:{trailId:string}) {
  const [rows,setRows]=useState<EraEvent[]>([]),[error,setError]=useState(''),[count,setCount]=useState(100);
  const [search,setSearch]=useState('');
  useEffect(()=>watchEraAudit(trailId,count,rows=>{setRows(rows);setError('');},e=>setError(e.message)),[trailId,count]);
  const indexed=useMemo(()=>rows.map(row=>({row,text:auditSearchText(row)})),[rows]);
  const filtered=useMemo(()=>indexed.filter(item=>matchesAuditSearch(item.text,search)).map(item=>item.row),[indexed,search]);
  return <section className="era-audit" aria-label="Audit log"><label className="era-audit-search"><span className="sr-only">Search audit log</span><svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.7"><circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/></svg><input type="search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search names, actions, dates or times…"/></label>
    {error && <p className="notice error" role="alert">{error}</p>}<p>{filtered.length} of {rows.length} loaded events</p><ol className="report-history">{filtered.map(r=><li key={r.id}><strong>{r.action.replaceAll('_',' ')}</strong><span>{r.createdAt?.toDate().toLocaleString()} · {r.actorEmail || r.actorId}</span><small>{r.recordId}</small>{r.note && <p>{r.note}</p>}</li>)}</ol>{rows.length>=count && <button className="button button-secondary" onClick={()=>setCount(c=>c+100)}>Load older events</button>}
  </section>;
}
