'use client';
import {useEffect,useRef,useState} from 'react';
import {eraCall,roleLabels,type EraAccess} from '@/lib/era';
import {ReportSelect} from './ReportSelect';

type Organisation = NonNullable<EraAccess['organisation']>;
type Member = EraAccess['members'][number];
type OrganisationForm = {id:string;name:string;trailIds:string[];active:boolean;creating:boolean;dirty:boolean};
type MemberForm = {email:string;roles:string[];editing:boolean;dirty:boolean};
type Removal = {email:string;legacy:boolean};
const responsibilities: Record<string,{label:string;description:string}> = {
  organisation_admin:{label:'Manage team',description:'Add members and manage their trail access.'},
  editor:{label:'Edit trail data',description:'Upload, edit and submit route revisions.'},
  verifier:{label:'Verify & publish',description:'Approve and publish revisions by other editors.'},
  incident_manager:{label:'Manage incidents',description:'Review incidents and publish warnings.'},
  viewer:{label:'View trail & audit',description:'Read trail data and its audit history.'},
};

export function EraAccessManager({access,trailId,onChanged}:{access:EraAccess;trailId:string;onChanged:()=>Promise<void>}) {
  const organisations:Organisation[]=access.admin?access.organisations:access.organisation?[access.organisation]:[];
  const [organisationId,setOrganisationId]=useState(access.organisation?.id || organisations[0]?.id || '');
  const [organisationForm,setOrganisationForm]=useState<OrganisationForm|null>(null);
  const [memberForm,setMemberForm]=useState<MemberForm|null>(null),[removal,setRemoval]=useState<Removal|null>(null);
  const [busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
  const organisation=organisations.find(o=>o.id===organisationId) || organisations[0] || null;
  const trailName=access.trails.find(t=>t.id===trailId)?.name || 'this trail';
  const members=access.members.filter(m=>m.organisationId===organisation?.id && m.trailRoles[trailId]?.length)
    .sort((a,b)=>a.email.localeCompare(b.email));
  const legacyMembers=access.admin?access.legacyMembers.filter(m=>m.trailIds.includes(trailId)):[];
  const assigned=!!organisation?.trailIds.includes(trailId),canAdd=assigned && organisation?.active;
  const dirty=!!(organisationForm?.dirty || memberForm?.dirty);
  useEffect(()=>{
    const warn=(event:BeforeUnloadEvent)=>{if(dirty){event.preventDefault();event.returnValue='';}};
    window.addEventListener('beforeunload',warn);return()=>window.removeEventListener('beforeunload',warn);
  },[dirty]);
  function discard(){return !dirty || window.confirm('Discard unsaved changes?');}
  function beginOrganisation(current?:Organisation){
    if(!discard())return;
    setMemberForm(null);setRemoval(null);setError('');setMessage('');
    setOrganisationForm(current?{...current,creating:false,dirty:false}:{id:crypto.randomUUID(),name:'',trailIds:trailId?[trailId]:[],active:true,creating:true,dirty:false});
  }
  function beginMember(current?:Member){
    if(!discard())return;
    setOrganisationForm(null);setRemoval(null);setError('');setMessage('');
    setMemberForm({email:current?.email || '',roles:current?.trailRoles[trailId] || ['viewer'],editing:!!current,dirty:false});
  }
  async function act(task:()=>Promise<void>,success:string){
    if(busy)return;
    setBusy(true);setError('');setMessage('');
    try {await task();await onChanged();setMessage(success);}
    catch(e){setError(e instanceof Error?e.message:'Could not save access.');}
    finally{setBusy(false);}
  }
  async function saveOrganisation(){
    const form=organisationForm;if(!form)return;
    await act(async()=>{
      await eraCall('configureEraOrganisation',{organisationId:form.id,name:form.name,trailIds:form.trailIds,active:form.active});
      setOrganisationId(form.id);setOrganisationForm(null);
    },form.creating?'Organisation added.':'Organisation updated.');
  }
  async function saveMember(){
    const form=memberForm;if(!form || !organisation)return;
    await act(async()=>{
      await eraCall('setEraMember',{email:form.email,organisationId:organisation.id,trailId,roles:form.roles});
      setMemberForm(null);
    },form.editing?'Member access updated.':'Member added.');
  }
  async function removeMember(){
    if(!removal || (!removal.legacy && !organisation))return;
    await act(async()=>{
      if(removal.legacy)await eraCall('setTrailReportAccess',{email:removal.email,trailId,grant:false});
      else await eraCall('setEraMember',{email:removal.email,organisationId:organisation!.id,trailId,roles:[]});
      setRemoval(null);setMemberForm(null);
    },'Trail access removed.');
  }
  return <section className="era-access" data-era-dirty={dirty?'true':'false'}>
    <section className="form-panel">
      <div className="era-section-heading"><h2>Organisation & access</h2>{access.admin && <button type="button" className="button button-secondary" disabled={busy} onClick={()=>beginOrganisation()}>Add organisation</button>}</div>
      {error && <p className="notice error" role="alert">{error}</p>}{message && <p className="notice" role="status">{message}</p>}
      {organisation?<div className="era-organisation-summary">
        {organisations.length>1?<ReportSelect label="Organisation" value={organisation.id} disabled={busy} onChange={id=>{if(!discard())return;setOrganisationId(id);setOrganisationForm(null);setMemberForm(null);setRemoval(null);setError('');setMessage('');}} options={organisations.map(o=>({value:o.id,label:`${o.name}${o.active?'':' · Inactive'}`}))}/>:<div><p className="era-field-caption">Organisation</p><h3>{organisation.name}</h3></div>}
        <div className="era-organisation-status"><span className={`era-status${organisation.active?'':' is-inactive'}`}>{organisation.active?'Active':'Inactive'}</span><span>{organisation.trailIds.length} assigned {organisation.trailIds.length===1?'trail':'trails'}</span>{access.admin && <button type="button" className="text-button" disabled={busy} onClick={()=>beginOrganisation(organisation)}>Edit organisation</button>}</div>
      </div>:!organisationForm && <div className="era-access-empty"><h3>Add your first organisation</h3><p>Assign its trails, then add the team.</p></div>}
      {organisationForm && <form className="era-access-form" onSubmit={event=>{event.preventDefault();void saveOrganisation();}} onChange={()=>setOrganisationForm(f=>f && {...f,dirty:true})}>
        <h3>{organisationForm.creating?'New organisation':'Edit organisation'}</h3>
        <fieldset disabled={busy}><div className="form-grid"><label>Organisation name<input autoFocus required maxLength={160} value={organisationForm.name} onChange={e=>setOrganisationForm(f=>f && {...f,name:e.target.value})}/></label></div>
          <fieldset className="era-trail-assignments"><legend>Assigned trails</legend>{access.trails.map(t=><label key={t.id} className="checkbox-row"><input type="checkbox" checked={organisationForm.trailIds.includes(t.id)} onChange={e=>setOrganisationForm(f=>f && {...f,trailIds:e.target.checked?[...f.trailIds,t.id]:f.trailIds.filter(id=>id!==t.id)})}/>{t.name}</label>)}</fieldset>
          <label className="checkbox-row"><input type="checkbox" checked={organisationForm.active} onChange={e=>setOrganisationForm(f=>f && {...f,active:e.target.checked})}/>Organisation active</label>
        </fieldset>
        <div className="era-actions"><button className="button button-primary" disabled={busy || (organisationForm.active && !organisationForm.trailIds.length)}>{busy?'Saving…':organisationForm.creating?'Add organisation':'Save organisation'}</button><button type="button" className="button button-secondary" disabled={busy} onClick={()=>{if(discard())setOrganisationForm(null);}}>Cancel</button></div>
      </form>}
    </section>
    {organisation && <section className="form-panel">
      <div className="era-section-heading"><div><h2>Team members</h2><p>{trailName}</p></div><button type="button" className="button button-primary" disabled={busy || !canAdd} onClick={()=>beginMember()}>Add member</button></div>
      {!organisation.active && <p className="notice">This organisation is inactive. Existing trail access is suspended.</p>}
      {!assigned && <p className="notice">This organisation is not assigned to {trailName}.{access.admin && <> <button type="button" className="text-button" onClick={()=>beginOrganisation(organisation)}>Edit trail assignments</button></>}</p>}
      {memberForm && <form className="era-access-form" onSubmit={event=>{event.preventDefault();void saveMember();}} onChange={()=>setMemberForm(f=>f && {...f,dirty:true})}>
        <h3>{memberForm.editing?'Edit member access':'Add member'}</h3>
        <fieldset disabled={busy}><div className="form-grid"><label>Account email<input autoFocus type="email" required disabled={memberForm.editing} value={memberForm.email} onChange={e=>setMemberForm(f=>f && {...f,email:e.target.value})}/><small>Use a verified EuroTrex account.</small></label></div>
          <fieldset className="era-role-options"><legend>Responsibilities for {trailName}</legend><div className="era-role-grid">{Object.entries(responsibilities).map(([id,r])=><label key={id} className="checkbox-row era-role-option"><input type="checkbox" checked={memberForm.roles.includes(id)} onChange={e=>setMemberForm(f=>f && {...f,roles:e.target.checked?[...f.roles,id]:f.roles.filter(v=>v!==id)})}/><span><strong>{r.label}</strong><small>{r.description}</small></span></label>)}</div></fieldset>
        </fieldset>
        <div className="era-actions"><button className="button button-primary" disabled={busy || !memberForm.roles.length || !canAdd}>{busy?'Saving…':memberForm.editing?'Save access':'Add member'}</button><button type="button" className="button button-secondary" disabled={busy} onClick={()=>{if(discard())setMemberForm(null);}}>Cancel</button></div>
      </form>}
      {!members.length && !memberForm && <div className="era-access-empty"><h3>No members for this trail yet.</h3>{canAdd && <p>Add a member and choose their responsibilities.</p>}</div>}
      {!!members.length && <ul className="era-member-list">{members.map(member=><li key={member.id}><div><strong>{member.email}</strong><div className="era-member-roles">{member.trailRoles[trailId].map(role=><span key={role}>{responsibilities[role]?.label || roleLabels[role]}</span>)}</div></div><div className="era-member-actions"><button type="button" className="button button-secondary" disabled={busy || !canAdd} onClick={()=>beginMember(member)}>Edit access</button><button type="button" className="text-button" disabled={busy} onClick={()=>{if(!discard())return;setMemberForm(null);setRemoval({email:member.email,legacy:false});}}>Remove</button></div></li>)}</ul>}
      {removal && !removal.legacy && <RemovalNotice email={removal.email} trailName={trailName} busy={busy} onRemove={()=>void removeMember()} onCancel={()=>setRemoval(null)}/>}
    </section>}
    {!!legacyMembers.length && <section className="form-panel"><details><summary>Existing incident reviewers ({legacyMembers.length})</summary><ul className="era-member-list">{legacyMembers.map(member=><li key={member.id}><span>{member.email}</span><button type="button" className="text-button" disabled={busy} onClick={()=>{if(!discard())return;setRemoval({email:member.email,legacy:true});}}>Remove access</button></li>)}</ul></details>{removal?.legacy && <RemovalNotice email={removal.email} trailName={trailName} busy={busy} onRemove={()=>void removeMember()} onCancel={()=>setRemoval(null)}/>}</section>}
  </section>;
}
function RemovalNotice({email,trailName,busy,onRemove,onCancel}:{email:string;trailName:string;busy:boolean;onRemove:()=>void;onCancel:()=>void}) {
  const element=useRef<HTMLDivElement>(null);
  useEffect(()=>{element.current?.scrollIntoView({block:'nearest',behavior:'smooth'});element.current?.querySelector<HTMLButtonElement>('button')?.focus({preventScroll:true});},[email]);
  return <div ref={element} className="notice era-removal"><p>Remove {email} from {trailName}?</p><div className="era-actions"><button type="button" className="button button-secondary" disabled={busy} onClick={onCancel}>Cancel</button><button type="button" className="button button-primary" disabled={busy} onClick={onRemove}>{busy?'Removing…':'Remove trail access'}</button></div></div>;
}
