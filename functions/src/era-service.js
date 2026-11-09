import {createHash} from 'node:crypto';
import {FieldValue} from 'firebase-admin/firestore';
import {HttpsError} from 'firebase-functions/v2/https';
import {requireId, text, validateReport} from './report-model.js';
import {eraRoles, hasEraRole, hasVerificationAuthority, verificationAttestation, parseGeoJSON, revisionPayload, validateRevision, fingerprint, buildRelease, validateEraRoute, retainSectionVerification} from './era-model.js';

const allRoles = [...eraRoles];
const time = () => FieldValue.serverTimestamp();
const check = fn => {try {return fn();} catch(e) {throw new HttpsError('invalid-argument',e.message);}};
const rows = snapshot => snapshot.docs.map(d=>({id:d.id,...d.data()}));
export function createEraService({db,bucket,authService}) {
  async function permission(tx, auth, trailId, roles=allRoles) {
    if (auth.token.email_verified!==true) throw new HttpsError('permission-denied','Verify your email first.');
    const [admin,member,legacy] = await tx.getAll(db.doc(`admins/${auth.uid}`),db.doc(`eraMembers/${auth.uid}`),db.doc(`trailReportAccess/${auth.uid}`));
    const isAdmin = admin.exists || auth.token.admin===true;
    const m = member.data();
    const org = m?.organisationId ? await tx.get(db.doc(`eraOrganisations/${m.organisationId}`)) : null;
    const organisation = org?.exists ? {id:org.id,...org.data()} : null;
    const legacyAllowed = roles.includes('incident_manager') && legacy.data()?.trailIds?.includes(trailId);
    if (!isAdmin && !legacyAllowed && !hasEraRole(m,organisation,trailId,roles)) throw new HttpsError('permission-denied','You do not have this trail permission.');
    const trail=roles.length===1 && roles[0]==='verifier' ? await tx.get(db.doc(`trails/${trailId}`)) : null;
    const authority=trail?.data()?.verificationAuthority || null;
    if(trail && !hasVerificationAuthority(m,organisation,trailId,authority))throw new HttpsError('permission-denied','Verification requires a verifier assigned by the responsible organisation for this trail.');
    return {admin:isAdmin,organisationId:organisation?.id || null,organisationName:organisation?.name || null,member:m,authority};
  }
  async function publisher(tx,auth,trailId) {
    const p=await permission(tx,auth,trailId);
    if(!p.admin)throw new HttpsError('permission-denied','EuroTrex must check and publish mobile releases.');
    const trail=await tx.get(db.doc(`trails/${trailId}`));
    const authority=trail.data()?.verificationAuthority;
    const org=authority?.organisationId ? await tx.get(db.doc(`eraOrganisations/${authority.organisationId}`)) : null;
    if(!authority || !org?.data()?.active || !org.data().trailIds?.includes(trailId))throw new HttpsError('failed-precondition','The responsible organisation must be active and assigned to this trail.');
    return {...p,authority};
  }
  function audit(tx,auth,trailId,action,recordId,extra={}) {
    tx.create(db.collection('eraAudit').doc(),{trailId,action,recordId,actorId:auth.uid,actorEmail:auth.token.email || '',outcome:'success',createdAt:time(),...extra});
  }
  async function context(trailId,tx) {
    const root=db.doc(`trails/${trailId}`);
    const read=ref=>tx ? tx.get(ref) : ref.get();
    const [trail,stages,markers,excursions,detours]=await Promise.all([read(root),read(root.collection('stages')),read(root.collection('routeMarkers')),read(root.collection('excursions')),read(root.collection('detours'))]);
    if(!trail.exists) throw new HttpsError('not-found','Trail unavailable.');
    // Once a release exists its stage snapshot is the source for the next revision.
    const active=trail.data().publishedReleaseId;
    const stageRows=active ? rows(await read(root.collection('releases').doc(active).collection('stages'))) : rows(stages);
    const withChunks=async(type,snapshot)=>Promise.all(rows(snapshot).map(async row=>({...row,_chunks:rows(await read(root.collection(type).doc(row.id).collection('routeChunks'))).sort((a,b)=>a.chunkIndex-b.chunkIndex)})));
    return {stages:stageRows,markers:rows(markers),excursions:await withChunks('excursions',excursions),detours:await withChunks('detours',detours),totalDistanceKm:trail.data().totalDistanceKm || null};
  }
  const workspace = id => db.doc(`eraWorkspaces/${id}`);
  const revisionRef = (trail,id) => workspace(trail).collection('revisions').doc(id);
  async function payloadFor(revision) {
    const [bytes]=await bucket.file(revision.payloadPath).download();
    return JSON.parse(bytes.toString('utf8'));
  }
  async function transitionSections(auth,data,snapshot) {
    const trailId=data.trailId,id=snapshot.id,action=data.action;
    if(!['submit','request_changes','approve','verify_section'].includes(action))throw new HttpsError('invalid-argument','Unknown route action.');
    const payload=await payloadFor(snapshot.data()),summary=check(()=>validateEraRoute(payload));
    const note=check(()=>text(data.note || '',1500));
    const attestation=['approve','verify_section'].includes(action)?check(()=>verificationAttestation(data.attestation)):null;
    if(action==='request_changes' && !note)throw new HttpsError('invalid-argument','Explain the changes needed.');
    const section=action==='verify_section'?summary.sections.find(s=>s.id===data.sectionId):null;
    if(action==='verify_section' && !section)throw new HttpsError('not-found','Section unavailable.');
    if(action!=='request_changes' && (section?section.errors:summary.errors).length)throw new HttpsError('failed-precondition','Resolve route checks first.');
    await db.runTransaction(async tx=>{
      const p=await permission(tx,auth,trailId,action==='submit'?['editor']:['verifier']);
      const [current,head]=await tx.getAll(snapshot.ref,workspace(trailId));
      const r=current.data();
      if(head.data()?.latestRevisionId!==id || r.payloadHash!==summary.payloadHash)throw new HttpsError('aborted','Newer changes exist. Open the latest draft.');
      const states={submit:['draft'],request_changes:['submitted','approved'],approve:['draft','submitted','approved'],verify_section:['draft','submitted','approved']};
      if(!states[action].includes(r.state))throw new HttpsError('failed-precondition','This revision is not ready for that action.');
      const stamp=attestation?{...attestation,status:'verified',...p.authority,authorityHash:fingerprint(p.authority),verifiedBy:auth.uid,verifierName:auth.token.name || 'Authorised verifier',verifiedAt:time(),revisionId:id,payloadHash:summary.routeHash}:null;
      const values={updatedAt:time(),note};
      if(action==='submit')values.state='submitted';
      if(action==='request_changes'){values.state='changes_requested';values.verification=null;}
      if(stamp){
        const verified=retainSectionVerification(r,summary,p.authority);
        for(const row of section?[section]:summary.sections)verified[row.id]={...stamp,sectionHash:row.hash};
        values.sectionVerifications=verified;
        // Whole-route verification is explicit, binds section order and membership.
        if(action==='approve'){values.verification={...stamp,routeHash:summary.routeHash};values.state='approved';values.approveBy=auth.uid;values.approveAt=time();}
        else {values.verification=null;values.state='submitted';}
      }
      tx.update(snapshot.ref,values);
      audit(tx,auth,trailId,action==='verify_section'?'section_verified':action==='approve'?'country_route_verified':`route_${action}`,section?.id || id,{revisionId:id,sectionName:section?.name || null,note,routeHash:summary.routeHash});
    });
    return {saved:true};
  }
  return {
    permission,audit,
    getEraAccess:async ({auth}) => {
      const [admin,member,legacy,catalog]=await Promise.all([db.doc(`admins/${auth.uid}`).get(),db.doc(`eraMembers/${auth.uid}`).get(),db.doc(`trailReportAccess/${auth.uid}`).get(),db.collection('trails').get()]);
      if(auth.token.email_verified!==true) throw new HttpsError('permission-denied','Verify your email first.');
      const m=member.data();
      const org=m?.organisationId ? await db.doc(`eraOrganisations/${m.organisationId}`).get() : null;
      const organisation=org?.exists ? {id:org.id,...org.data()} : null;
      const isAdmin=admin.exists || auth.token.admin===true;
      const trails=rows(catalog).flatMap(t=>{
        const assigned=isAdmin ? allRoles : [...new Set([...(organisation?.active && organisation.trailIds?.includes(t.id) ? m?.trailRoles?.[t.id] || [] : []),...(legacy.data()?.trailIds?.includes(t.id)?['incident_manager']:[])])];
        const canVerify=hasVerificationAuthority(m,organisation,t.id,t.verificationAuthority);
        const roles=assigned.filter(role=>role!=='verifier' || canVerify);
        return roles.length ? [{id:t.id,name:t.name || t.id,roles,verificationAuthority:t.verificationAuthority || null,publishedReleaseId:t.publishedReleaseId || null,canPrepare:isAdmin}] : [];
      });
      const canManage=isAdmin || (organisation?.active && Object.entries(m?.trailRoles || {}).some(([id,v])=>organisation.trailIds?.includes(id) && v.includes('organisation_admin')));
      return {admin:isAdmin,organisation:organisation && {id:organisation.id,name:organisation.name,trailIds:organisation.trailIds,active:organisation.active},trails,
        organisations:isAdmin ? rows(await db.collection('eraOrganisations').get()) : [],
        members:canManage ? rows(await (isAdmin ? db.collection('eraMembers') : db.collection('eraMembers').where('organisationId','==',m.organisationId)).get()) : [],
        legacyMembers:isAdmin ? rows(await db.collection('trailReportAccess').get()) : []};
    },
    searchEraAudit:async ({auth,data})=>{
      const trailId=check(()=>requireId(data.trailId));
      await db.runTransaction(tx=>permission(tx,auth,trailId));
      const search=check(()=>text(data.search || '',200)).toLocaleLowerCase().split(/\s+/).filter(Boolean);
      let query=db.collection('eraAudit').where('trailId','==',trailId).orderBy('createdAt','desc');
      if(data.cursor){const cursor=await db.doc(`eraAudit/${check(()=>requireId(data.cursor))}`).get();if(!cursor.exists || cursor.data().trailId!==trailId)throw new HttpsError('invalid-argument','Invalid history cursor.');query=query.startAfter(cursor);}
      const page=await query.limit(500).get();
      const events=rows(page).filter(row=>{const value=JSON.stringify({...row,createdAt:row.createdAt?.toDate().toISOString()}).toLocaleLowerCase();return search.every(term=>value.includes(term)) && (!data.action || row.action===data.action);}).slice(0,100);
      const last=events.length===100?events.at(-1).id:page.docs.at(-1)?.id;
      return {events:events.map(row=>({...row,createdAtMs:row.createdAt?.toMillis(),createdAt:null})),cursor:page.size===500 || events.length===100 ? last:null};
    },
    exportEraVerifiedRoute:async ({auth,data})=>{
      const trailId=check(()=>requireId(data.trailId)),id=check(()=>requireId(data.revisionId));
      const snapshot=await db.runTransaction(async tx=>{
        const p=await permission(tx,auth,trailId,['verifier']);
        const [r,head]=await tx.getAll(revisionRef(trailId,id),workspace(trailId));
        if(!r.exists || r.data().sectionSchema!==1 || !['approved','published'].includes(r.data().state) || head.data()?.latestRevisionId!==id || !r.data().verification || r.data().verification.authorityHash!==fingerprint(p.authority))throw new HttpsError('failed-precondition','Verify the current country route first.');
        audit(tx,auth,trailId,'osm_export_prepared',id,{routeHash:r.data().routeHash});return r;
      });
      const payload=await payloadFor(snapshot.data());
      const summary=validateEraRoute(payload);
      if(summary.routeHash!==snapshot.data().verification.routeHash)throw new HttpsError('failed-precondition','The geometry no longer matches verification.');
      return {sections:payload.sections,segments:payload.segments,verification:{organisationName:snapshot.data().verification.organisationName,country:snapshot.data().verification.country,scope:snapshot.data().verification.scope,verifiedAt:snapshot.data().verification.verifiedAt.toDate().toISOString()},routeHash:summary.routeHash};
    },
    configureEraOrganisation:async ({auth,data}) => {
      const id=check(()=>requireId(data.organisationId));
      const name=check(()=>text(data.name,160,true));
      if(!Array.isArray(data.trailIds) || data.trailIds.length>30 || typeof data.active!=='boolean') throw new HttpsError('invalid-argument','Choose assigned trails and organisation status.');
      const trailIds=[...new Set(data.trailIds.map(v=>check(()=>requireId(v))))];
      await db.runTransaction(async tx=>{
        const admin=await tx.get(db.doc(`admins/${auth.uid}`));
        if(auth.token.email_verified!==true || (!admin.exists && auth.token.admin!==true)) throw new HttpsError('permission-denied','EuroTrex administrator access required.');
        const trails=await Promise.all(trailIds.map(t=>tx.get(db.doc(`trails/${t}`))));
        const previous=await tx.get(db.doc(`eraOrganisations/${id}`));
        if(trails.some(t=>!t.exists)) throw new HttpsError('invalid-argument','Unknown trail.');
        tx.set(db.doc(`eraOrganisations/${id}`),{name,trailIds,active:data.active,confirmedBy:auth.uid,updatedAt:time()});
        audit(tx,auth,'_organisations','organisation_configured',id,{trailIds});
        for(const trailId of new Set([...trailIds,...(previous.data()?.trailIds || [])]))audit(tx,auth,trailId,'organisation_configured',id,{active:data.active,trailIds});
      });
      return {saved:true};
    },
    setEraTrailAuthority:async ({auth,data}) => {
      const trailId=check(()=>requireId(data.trailId)),organisationId=check(()=>requireId(data.organisationId));
      const country=check(()=>text(data.country,100,true)),scope=check(()=>text(data.scope,200,true));
      await db.runTransaction(async tx=>{
        const p=await permission(tx,auth,trailId,['organisation_admin']);
        if(!p.admin)throw new HttpsError('permission-denied','A EuroTrex administrator must record the responsible organisation.');
        const [org,trail]=await tx.getAll(db.doc(`eraOrganisations/${organisationId}`),db.doc(`trails/${trailId}`));
        if(!trail.exists || !org.data()?.active || !org.data().trailIds?.includes(trailId))throw new HttpsError('failed-precondition','Assign this trail to an active organisation first.');
        const authority={organisationId,organisationName:org.data().name,country,scope};
        tx.update(trail.ref,{verificationAuthority:authority});
        audit(tx,auth,trailId,'verification_authority_assigned',organisationId,{previousAuthority:trail.data().verificationAuthority || null,authority});
      });
      return {saved:true};
    },
    setEraMember:async ({auth,data}) => {
      const organisationId=check(()=>requireId(data.organisationId));
      const trailId=check(()=>requireId(data.trailId));
      if(!Array.isArray(data.roles) || data.roles.some(r=>!eraRoles.includes(r))) throw new HttpsError('invalid-argument','Choose valid roles.');
      await db.runTransaction(tx=>permission(tx,auth,trailId,['organisation_admin']));
      let target;
      try {target=await authService.getUserByEmail(check(()=>text(data.email,254,true)));} catch {throw new HttpsError('not-found','Create and verify this account at /era first.');}
      if(!target.emailVerified || target.disabled) throw new HttpsError('failed-precondition','The account must be active and verified.');
      await db.runTransaction(async tx=>{
        const p=await permission(tx,auth,trailId,['organisation_admin']);
        const [org,current]=await tx.getAll(db.doc(`eraOrganisations/${organisationId}`),db.doc(`eraMembers/${target.uid}`));
        if(!p.admin && p.organisationId!==organisationId) throw new HttpsError('permission-denied','Choose your own organisation.');
        if(!org.data()?.active || !org.data().trailIds.includes(trailId)) throw new HttpsError('failed-precondition','The organisation is not assigned this trail.');
        if(current.exists && current.data().organisationId!==organisationId) throw new HttpsError('failed-precondition','This account already belongs to another organisation.');
        const trailRoles={...current.data()?.trailRoles,[trailId]:[...new Set(data.roles)]};
        tx.set(current.ref,{email:target.email,organisationId,trailRoles,updatedAt:time()});
        audit(tx,auth,trailId,'member_roles_changed',target.uid,{organisationId,previousRoles:current.data()?.trailRoles?.[trailId] || [],roles:data.roles});
      });
      return {saved:true};
    },
    saveEraRevision:async ({auth,data}) => {
      const trailId=check(()=>requireId(data.trailId));
      await db.runTransaction(tx=>permission(tx,auth,trailId,['editor']));
      if(data.preparation===true)await db.runTransaction(tx=>publisher(tx,auth,trailId));
      const raw=typeof data.originalGeoJSON==='string' ? data.originalGeoJSON : null;
      if(raw && Buffer.byteLength(raw)>8*1024*1024) throw new HttpsError('invalid-argument','GeoJSON must be smaller than 8 MB.');
      if(raw)check(()=>parseGeoJSON(JSON.parse(raw)));
      const body=check(()=>revisionPayload(raw ? {...data,segments:data.segments || parseGeoJSON(JSON.parse(raw))} : data));
      const ctx=await context(trailId);
      const validation=check(()=>body.sectionSchema===1?validateEraRoute(body):validateRevision(body,ctx));
      validation.contextHash=fingerprint(ctx);
      const ref=workspace(trailId).collection('revisions').doc();
      const payloadPath=`era-private/${trailId}/${ref.id}/payload.json`;
      const originalFiles=Array.isArray(data.originalFiles)?data.originalFiles:[];
      if(originalFiles.length>50 || originalFiles.reduce((n,f)=>n+(typeof f?.content==='string'?Buffer.byteLength(f.content):9*1024*1024),0)>8*1024*1024)throw new HttpsError('invalid-argument','Original files exceed the upload limit.');
      const originalObjects=originalFiles.map((f,i)=>{
        const name=check(()=>text(f.name,200,true)),path=`era-private/${trailId}/${ref.id}/original-${i}`,hash=createHash('sha256').update(f.content).digest('hex');
        if(body.sectionSchema===1 && !body.sections.some(s=>s.originalHash===hash && s.originalFilename===name))throw new HttpsError('invalid-argument','Original file does not match its section.');
        return {name,path,hash};
      });
      const originalPath=raw ? `era-private/${trailId}/${ref.id}/original.geojson` : null;
      try {
        await bucket.file(payloadPath).save(JSON.stringify(body),{resumable:false,metadata:{contentType:'application/json',cacheControl:'private, no-store'}});
        for(let i=0;i<originalObjects.length;i++)await bucket.file(originalObjects[i].path).save(originalFiles[i].content,{resumable:false,metadata:{contentType:'application/octet-stream',cacheControl:'private, no-store'}});
        if(raw)await bucket.file(originalPath).save(raw,{resumable:false,metadata:{contentType:'application/geo+json',cacheControl:'private, no-store'}});
        await db.runTransaction(async tx=>{
          const p=await permission(tx,auth,trailId,['editor']);
          const [head,trail]=await tx.getAll(workspace(trailId),db.doc(`trails/${trailId}`));
          if(data.expectedReleaseId!==undefined && (trail.data()?.publishedReleaseId || null)!==data.expectedReleaseId)throw new HttpsError('aborted','The published release changed. Reload first.');
          if((head.data()?.latestRevisionId || null)!==(data.expectedRevisionId || null)) throw new HttpsError('aborted','Another editor saved a revision. Reload before saving.');
          const prior=head.data()?.latestRevisionId ? await tx.get(revisionRef(trailId,head.data().latestRevisionId)) : null;
          if(fingerprint(await context(trailId,tx))!==validation.contextHash) throw new HttpsError('aborted','Trail data changed. Reload before saving.');
          const contributors=[...new Set([...(prior?.data()?.contributors || []),auth.uid])];
          const sectionVerifications=body.sectionSchema===1?retainSectionVerification(prior?.data(),validation,trail.data().verificationAuthority || null):{};
          const previousVerification=prior?.data()?.verification;
          const verification=body.sectionSchema===1 && previousVerification?.routeHash===validation.routeHash && previousVerification.authorityHash===fingerprint(trail.data().verificationAuthority || null) ? previousVerification : null;
          tx.create(ref,{trailId,state:verification?'approved':'draft',verification,...(body.sectionSchema===1?{sectionSchema:1,sections:validation.sections,sectionVerifications,routeHash:validation.routeHash}:{}),payloadPath,preparedBy:data.preparation===true && p.admin?auth.uid:null,preparedRouteHash:data.preparation===true && p.admin?validation.routeHash || null:null,originalObjects:[...(prior?.data()?.originalObjects || []).filter(o=>body.sections?.some(s=>s.originalHash===o.hash)),...originalObjects],originalPath:originalPath || prior?.data()?.originalPath || null,
            sourceHash:raw ? createHash('sha256').update(raw).digest('hex') : prior?.data()?.sourceHash || null, payloadHash:validation.payloadHash,contextHash:validation.contextHash,
            baseReleaseId:trail.data()?.publishedReleaseId || null,contributors,organisationId:p.organisationId,
            source:body.source,sourceType:body.sourceType || 'unknown',sourceUrl:body.sourceUrl || '',attribution:body.attribution,elevationSource:body.elevationSource,pointCount:validation.pointCount,totalDistanceKm:validation.totalDistanceKm,
            errors:validation.errors,warnings:validation.warnings,createdBy:auth.uid,createdAt:time(),updatedAt:time()});
          tx.set(workspace(trailId),{latestRevisionId:ref.id,updatedAt:time()},{merge:true});
          audit(tx,auth,trailId,raw?'geojson_uploaded':'revision_saved',ref.id,{organisationId:p.organisationId,payloadHash:validation.payloadHash,previousRevisionId:prior?.id || null,...(body.sectionSchema===1?{sections:validation.sections.map(row=>({id:row.id,name:row.name,hash:row.hash,totalDistanceKm:row.totalDistanceKm})),previousSections:prior?.data()?.sections?.map(row=>({id:row.id,name:row.name,hash:row.hash,totalDistanceKm:row.totalDistanceKm})) || []}:{})});
        });
      } catch(e) {await Promise.all([payloadPath,...originalObjects.map(o=>o.path),...(originalPath?[originalPath]:[])].map(path=>bucket.file(path).delete().catch(()=>{})));throw e;}
      return {revisionId:ref.id};
    },
    getEraRevision:async ({auth,data}) => {
      const trailId=check(()=>requireId(data.trailId)),id=check(()=>requireId(data.revisionId));
      const revision=await db.runTransaction(async tx=>{await permission(tx,auth,trailId);return tx.get(revisionRef(trailId,id));});
      if(!revision.exists) throw new HttpsError('not-found','Revision unavailable.');
      const body=await payloadFor(revision.data());
      // Viewing/editing geometry does not need an expensive context-wide review.
      // Permission checks above are identical for both modes; publishing always revalidates.
      if(data.payloadOnly===true)return {payload:body};
      const ctx=await context(trailId);
      const validation=check(()=>body.sectionSchema===1 && !data.preparation?validateEraRoute(body):validateRevision(body,ctx));
      return {payload:body,validation:{errors:validation.errors,warnings:validation.warnings,stageLinks:validation.stageLinks,pointCount:validation.pointCount,totalDistanceKm:validation.totalDistanceKm},relatedRoutes:{excursions:ctx.excursions.map(v=>({id:v.id,name:v.name || v.id})),detours:ctx.detours.map(v=>({id:v.id,name:v.name || v.id}))}};
    },
    transitionEraRevision:async ({auth,data}) => {
      const trailId=check(()=>requireId(data.trailId)),id=check(()=>requireId(data.revisionId));
      const action=data.action;
      const candidate=await db.runTransaction(async tx=>{await permission(tx,auth,trailId);return tx.get(revisionRef(trailId,id));});
      if(candidate.data()?.sectionSchema===1 && action!=='publish')return transitionSections(auth,data,candidate);
      if(!['submit','request_changes','approve','publish'].includes(action)) throw new HttpsError('invalid-argument','Unknown revision action.');
      const note=check(()=>text(data.note || '',1500));
      if(action==='request_changes' && !note) throw new HttpsError('invalid-argument','Explain the requested changes.');
      await db.runTransaction(tx=>action==='publish'?publisher(tx,auth,trailId):permission(tx,auth,trailId,action==='submit'?['editor']:['verifier']));
      const snap=await revisionRef(trailId,id).get();
      if(!snap.exists) throw new HttpsError('not-found','Revision unavailable.');
      const payload=await payloadFor(snap.data()),ctx=await context(trailId);
      const attestation=action==='approve' ? check(()=>verificationAttestation(data.attestation)) : null;
      if(['submit','approve'].includes(action) && (!payload.sourceType || payload.sourceType==='unknown'))throw new HttpsError('failed-precondition','Choose the route source type and save a new draft first.');
      const validation=check(()=>validateRevision(payload,ctx));
      if(action!=='request_changes' && validation.errors.length) throw new HttpsError('failed-precondition','Resolve validation errors before continuing.');
      if(action!=='request_changes' && (validation.contextHash!==snap.data().contextHash || validation.payloadHash!==snap.data().payloadHash)) throw new HttpsError('failed-precondition','Trail data changed. Save and submit a new revision.');
      let release=null;
      const releaseRef=db.collection(`trails/${trailId}/releases`).doc();
      if(action==='publish') {
        if(snap.data().sectionSchema===1 && (!snap.data().preparedBy || snap.data().preparedRouteHash!==snap.data().routeHash))throw new HttpsError('failed-precondition','EuroTrex must save and check mobile preparation first.');
        if(snap.data().state!=='approved') throw new HttpsError('failed-precondition','Approve the revision first.');
        if(!snap.data().verification)throw new HttpsError('failed-precondition','This earlier approval has no organisation verification. Save a new draft for verification.');
        release=check(()=>buildRelease(validation));
        // Invisible until the final transaction marks the manifest published.
        const writer=db.bulkWriter();
        release.chunks.forEach((c,i)=>writer.create(releaseRef.collection('routeChunks').doc(String(i).padStart(5,'0')),c));
        release.stages.forEach(({id:stageId,...s})=>writer.create(releaseRef.collection('stages').doc(stageId),s));
        writer.create(releaseRef.collection('routeMetadata').doc('main'),release.metadata);
        for(const type of ['excursions','detours'])for(const {_chunks,id:relatedId,...row} of validation.related[type]) {
          const relatedRef=releaseRef.collection(type).doc(relatedId);
          writer.create(relatedRef,row);
          for(const {id:chunkId,...chunk} of _chunks)writer.create(relatedRef.collection('routeChunks').doc(chunkId),chunk);
        }
        validation.stageLinks.forEach(link=>writer.create(releaseRef.collection('routeMarkers').doc(link.stageId),{stageId:link.stageId,stageName:link.name,pointIndex:link.pointIndex,distanceKm:link.accumulatedDistanceKm,reverseDistanceKm:validation.totalDistanceKm-link.accumulatedDistanceKm,location:link.location}));
        await writer.close();
      }
      await db.runTransaction(async tx=>{
        const p=action==='publish'?await publisher(tx,auth,trailId):await permission(tx,auth,trailId,action==='submit'?['editor']:['verifier']);
        const [latest,head,trail]=await tx.getAll(snap.ref,workspace(trailId),db.doc(`trails/${trailId}`));
        const r=latest.data();
        if(head.data()?.latestRevisionId!==id) throw new HttpsError('aborted','A newer revision exists.');
        if((trail.data().publishedReleaseId || null)!==r.baseReleaseId) throw new HttpsError('aborted','The published trail changed. Save a new revision.');
        if(action!=='request_changes' && fingerprint(await context(trailId,tx))!==r.contextHash) throw new HttpsError('aborted','Trail records changed. Save and submit a new revision.');
        const states={submit:['draft'],request_changes:['submitted'],approve:['draft','submitted'],publish:['approved']};
        if(!states[action].includes(r.state)) throw new HttpsError('failed-precondition','This revision is not ready for that action.');
        const state={submit:'submitted',request_changes:'changes_requested',approve:'approved',publish:'published'}[action];
        if(action==='publish' && (!r.verification || (r.sectionSchema===1 ? r.verification.routeHash!==validateEraRoute(payload).routeHash : r.verification.payloadHash!==r.payloadHash) || r.verification.authorityHash!==fingerprint(p.authority)))throw new HttpsError('failed-precondition','This revision needs verification by the currently responsible organisation. Save a new draft for verification.');
        const verification=action==='approve' ? {...attestation,status:'verified',...p.authority,authorityHash:fingerprint(p.authority),verifiedBy:auth.uid,verifierName:auth.token.name || 'Authorised verifier',verifiedAt:time(),revisionId:id,payloadHash:r.payloadHash} : null;
        tx.update(snap.ref,{state,...(verification?{verification}:{}),updatedAt:time(),[`${action}By`]:auth.uid,[`${action}At`]:time(),[`${action}OrganisationName`]:p.organisationName,note});
        if(action==='publish') {
          tx.create(releaseRef,{published:true,revisionId:id,source:payload.source,attribution:payload.attribution,elevationSource:payload.elevationSource,
            sourceType:payload.sourceType || 'unknown',sourceUrl:payload.sourceUrl || '',verification:r.sectionSchema===1?{...r.verification,routeRevisionId:r.verification.revisionId,routePayloadHash:r.verification.payloadHash,revisionId:id,payloadHash:r.payloadHash}:r.verification,...(r.sectionSchema===1?{sectionVerifications:r.sectionVerifications,routeHash:r.routeHash}:{}),
            approvedBy:r.approveBy || r.verification.verifiedBy,approvedAt:r.approveAt || r.verification.verifiedAt,verifyingOrganisationName:r.verification.organisationName,publishedBy:auth.uid,publishedAt:time(),payloadHash:r.payloadHash,stageCount:release.stages.length,...release.metadata});
          tx.update(trail.ref,{publishedReleaseId:releaseRef.id,totalDistanceKm:validation.totalDistanceKm,maxAltitudeM:release.metadata.maxAltitudeM,stageCount:release.stages.length,updatedAt:time()});
        }
        audit(tx,auth,trailId,`revision_${action==='approve'?'verified':state}`,id,{organisationId:p.organisationId,note,payloadHash:r.payloadHash,...(verification?{verificationAuthority:p.authority,criteriaVersion:verification.criteriaVersion}:{})});
      });
      return {saved:true};
    },
    rollbackEraRelease:async ({auth,data}) => {
      const trailId=check(()=>requireId(data.trailId)),id=check(()=>requireId(data.releaseId)),note=check(()=>text(data.note,1500,true));
      await db.runTransaction(async tx=>{
        await publisher(tx,auth,trailId);
        const [release,trail]=await tx.getAll(db.doc(`trails/${trailId}/releases/${id}`),db.doc(`trails/${trailId}`));
        if(!release.data()?.published) throw new HttpsError('failed-precondition','Choose a complete published release.');
        if(trail.data()?.publishedReleaseId!==data.expectedReleaseId) throw new HttpsError('aborted','The published trail changed. Reload first.');
        tx.update(trail.ref,{publishedReleaseId:id,totalDistanceKm:release.data().totalDistanceKm,maxAltitudeM:release.data().maxAltitudeM,stageCount:release.data().stageCount,updatedAt:time()});
        audit(tx,auth,trailId,'release_restored',id,{note,previousReleaseId:trail.data().publishedReleaseId});
      });
      return {saved:true};
    },
    createEraIncident:async ({auth,data}) => {
      const body=check(()=>validateReport({...data,locationSource:'pin',contactEmail:'',photoIds:data.photoIds || [],appVersion:'era-web'}));
      if(!['normal','high','urgent'].includes(data.priority)) throw new HttpsError('invalid-argument','Choose a priority.');
      const ref=data.reportId ? db.doc(`trailReports/${check(()=>requireId(data.reportId))}`) : db.collection('trailReports').doc();
      const contentHash=fingerprint({...body,priority:data.priority});
      await db.runTransaction(async tx=>{
        const p=await permission(tx,auth,body.trailId,['incident_manager']);
        const trail=await tx.get(db.doc(`trails/${body.trailId}`));
        const existing=await tx.get(ref);
        if(existing.exists) {
          if(existing.data().creatorUid!==auth.uid || existing.data().fingerprint!==contentHash)throw new HttpsError('already-exists','This incident identifier is already in use.');
          return;
        }
        if(!trail.exists) throw new HttpsError('not-found','Trail unavailable.');
        const stagePrefix=trail.data().publishedReleaseId ? `trails/${body.trailId}/releases/${trail.data().publishedReleaseId}` : `trails/${body.trailId}`;
        if(body.stageId && !(await tx.get(db.doc(`${stagePrefix}/stages/${body.stageId}`))).exists) throw new HttpsError('invalid-argument','Unknown stage.');
        tx.create(ref,{...body,origin:'organisation',organisationId:p.organisationId,creatorUid:auth.uid,reporterUid:auth.uid,routeReleaseId:trail.data().publishedReleaseId || null,
          uploadState:body.photoIds.length?'uploading':'complete',status:'new',priority:data.priority,photos:[],authority:'',forwardingReference:'',duplicateOf:null,publicWarning:false,fingerprint:contentHash,
          receivedAt:body.photoIds.length?null:time(),createdAt:time(),updatedAt:time()});
        tx.create(ref.collection('events').doc(),{action:'created',actorId:auth.uid,actorEmail:auth.token.email,createdAt:time()});
        audit(tx,auth,body.trailId,'incident_created',ref.id,{organisationId:p.organisationId});
      });
      return {reportId:ref.id};
    },
  };
}
