import {createHash} from 'node:crypto';
import {requireId, text} from './report-model.js';

export const eraRoles = ['organisation_admin', 'editor', 'verifier', 'incident_manager', 'viewer'];
export const verificationCriteriaVersion = 'era-e-path-article7-2024-09';
export const verificationCriteria = ['marking','maintenance','authority_acceptance','mapped_description','public_transport','identity','sustainability','recreational_value'];
export function hasVerificationAuthority(member, organisation, trailId, authority) {
  return !!authority?.organisationId && authority.organisationId === organisation?.id
    && hasEraRole(member, organisation, trailId, ['verifier']);
}
export function verificationAttestation(value) {
  if (value?.criteriaVersion !== verificationCriteriaVersion || !verificationCriteria.every(key=>value.criteria?.[key] === true)) {
    throw new Error('Confirm each ERA criterion on behalf of the responsible organisation.');
  }
  return {criteriaVersion:verificationCriteriaVersion,criteria:Object.fromEntries(verificationCriteria.map(key=>[key,true]))};
}
function provenance(data) {
  // Omit new fields on old payloads to preserve their immutable content hashes.
  if(data.sourceType===undefined && data.sourceUrl===undefined)return {};
  if(!['member_organisation','community','other','unknown'].includes(data.sourceType))throw new Error('Choose a route source type.');
  const sourceUrl=text(data.sourceUrl || '',1000);
  if(sourceUrl){let url;try{url=new URL(sourceUrl);}catch{throw new Error('Enter a valid source link.');}if(!['https:','http:'].includes(url.protocol) || url.username || url.password)throw new Error('Use a public HTTP or HTTPS source link.');}
  return {sourceType:data.sourceType,sourceUrl};
}
export function hasEraRole(member, organisation, trailId, roles) {
  return organisation?.active === true && organisation.trailIds?.includes(trailId)
    && member?.organisationId === organisation.id
    && member?.trailRoles?.[trailId]?.some(role => roles.includes(role));
}
export function fingerprint(value) {
  const stable = v => Array.isArray(v) ? v.map(stable) : v && typeof v === 'object'
    ? Object.fromEntries(Object.keys(v).sort().map(k => [k, stable(v[k])])) : v;
  return createHash('sha256').update(JSON.stringify(stable(value))).digest('hex');
}
export function parseGeoJSON(input) {
  const lines = [];
  function visit(value) {
    if (!value || typeof value !== 'object') throw new Error('Invalid GeoJSON.');
    if (value.type === 'FeatureCollection') {
      if (!Array.isArray(value.features)) throw new Error('Missing features.');
      value.features.forEach(visit);
    } else if (value.type === 'Feature') visit(value.geometry);
    else if (value.type === 'GeometryCollection') {
      if (!Array.isArray(value.geometries)) throw new Error('Missing geometries.');
      value.geometries.forEach(visit);
    } else if (value.type === 'LineString') lines.push({kind: 'main', coordinates: value.coordinates});
    else if (value.type === 'MultiLineString') {
      if (!Array.isArray(value.coordinates)) throw new Error('Missing line coordinates.');
      value.coordinates.forEach(coordinates => lines.push({kind: 'main', coordinates}));
    } else throw new Error('Use LineString or MultiLineString GeoJSON.');
  }
  visit(input);
  return normaliseSegments(lines);
}
export function normaliseSegments(value) {
  if (!Array.isArray(value) || !value.length || value.length > 100) throw new Error('Use between 1 and 100 segments.');
  let count = 0;
  const segments = value.map(segment => {
    if (!['main', 'alternative'].includes(segment.kind) || !Array.isArray(segment.coordinates) || segment.coordinates.length < 2) throw new Error('Each segment needs at least two points and a route type.');
    const coordinates = segment.coordinates.map(point => {
      if (!Array.isArray(point) || point.length < 2 || point.length > 3 || !point.every(Number.isFinite)
        || Math.abs(point[0]) > 180 || Math.abs(point[1]) > 85 || (point.length === 3 && (point[2] < -500 || point[2] > 9000))) throw new Error('Invalid longitude, latitude or elevation. Use WGS84 coordinates.');
      count++;
      return [...point];
    });
    return {kind: segment.kind, coordinates};
  });
  if (count > 100000) throw new Error('Use at most 100,000 route points.');
  return segments;
}
export function distanceKm(a, b) {
  const rad = Math.PI / 180;
  const h = Math.sin((b[1]-a[1])*rad/2)**2 + Math.cos(a[1]*rad)*Math.cos(b[1]*rad)*Math.sin((b[0]-a[0])*rad/2)**2;
  return 12742 * Math.asin(Math.min(1, Math.sqrt(h)));
}
function nearest(point, route, distances, selectedIndex) {
  let best = null, near = [];
  for (let i = 0; i < route.length - 1; i++) {
    if (selectedIndex != null && i !== selectedIndex) continue;
    const a = route[i], b = route[i+1], scale = Math.cos(point[1]*Math.PI/180);
    const dx = (b[0]-a[0])*scale, dy = b[1]-a[1];
    const t = Math.max(0, Math.min(1, (((point[0]-a[0])*scale)*dx+(point[1]-a[1])*dy)/(dx*dx+dy*dy || 1)));
    const projected = [a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t];
    const candidate = {pointIndex:i, fraction:t, coordinates:projected, distanceFromPathKm:distanceKm(point, projected), accumulatedDistanceKm:distances[i]+(distances[i+1]-distances[i])*t,
      altitudeM:a[2] == null || b[2] == null ? null : a[2]+(b[2]-a[2])*t};
    if (!best || candidate.distanceFromPathKm < best.distanceFromPathKm) {best=candidate;near=near.filter(c=>c.distanceFromPathKm<=best.distanceFromPathKm+0.05);}
    if(candidate.distanceFromPathKm<=best.distanceFromPathKm+0.05)near.push(candidate);
  }
  return best && {...best, ambiguous:near.some(c=>Math.abs(c.accumulatedDistanceKm-best.accumulatedDistanceKm)>0.5 && Math.abs(c.distanceFromPathKm-best.distanceFromPathKm)<0.05)};
}
export function validateRevision(payload, context) {
  const segments = normaliseSegments(payload.segments);
  const errors = [], warnings = [], route = [];
  for (const [index, segment] of segments.entries()) {
    if (segment.kind !== 'main') continue;
    if (route.length && distanceKm(route.at(-1),segment.coordinates[0]) > 0.001) errors.push(`Gap before segment ${index+1}. Join or reclassify it explicitly.`);
    route.push(...segment.coordinates.slice(route.length && distanceKm(route.at(-1),segment.coordinates[0]) <= 0.001 ? 1 : 0));
  }
  if (route.length < 2) errors.push('Choose a main route with at least two points.');
  const distances = [0], ascent = [0], descent = [0];
  let duplicate = false, longLeg = false;
  for (let i=1; i<route.length; i++) {
    const d = distanceKm(route[i-1],route[i]);
    if (d < 0.00001) duplicate = true;
    if (d > 5) longLeg = true;
    distances.push(distances.at(-1)+d);
    const delta = route[i][2]-route[i-1][2];
    ascent.push(ascent.at(-1)+Math.max(0,delta || 0)); descent.push(descent.at(-1)+Math.max(0,-delta || 0));
  }
  if (duplicate) errors.push('Remove consecutive duplicate points.');
  if (longLeg) errors.push('A main-route leg exceeds 5 km. Add the missing geometry.');
  if (route.some(p=>p.length<3)) errors.push('Main-route elevation is missing. Supply elevation-enriched GeoJSON.');
  if (!payload.elevationSource?.trim()) errors.push('Record the elevation source.');
  if (!payload.source?.trim() || !payload.attribution?.trim()) errors.push('Record the route source and attribution.');
  const totalDistanceKm = distances.at(-1) || 0;
  if (context.totalDistanceKm && Math.abs(totalDistanceKm/context.totalDistanceKm-1)>0.2) warnings.push('Route distance changes by more than 20%.');
  const known=context.markers.map(m=>m.location).filter(Boolean);
  const area=known.length ? [Math.min(...known.map(l=>l.longitude))-2,Math.max(...known.map(l=>l.longitude))+2,Math.min(...known.map(l=>l.latitude))-2,Math.max(...known.map(l=>l.latitude))+2] : null;
  if(area && route.some(p=>p[0]<area[0] || p[0]>area[1] || p[1]<area[2] || p[1]>area[3]))warnings.push('Route extends substantially beyond the existing trail area.');
  if ((context.excursions?.length || context.detours?.length) && !payload.relatedRoutesReviewed) errors.push('Review affected excursions and detours.');
  const editedStages = new Map(context.stages.map(stage=>[stage.id,stage]));
  for(const stage of normaliseStageEdits(payload.stageEdits || [])) editedStages.set(stage.id,{...editedStages.get(stage.id),...stage});
  const stageRows = [...editedStages.values()];
  const stageLinks = stageRows.map(stage => {
    const decision = payload.stageDecisions?.[stage.id] || {};
    const marker = context.markers.find(m=>m.stageId===stage.id);
    const location = decision.location || stage.location || marker?.location;
    const point = location && [location.longitude,location.latitude];
    const valid = point?.every(Number.isFinite) && Math.abs(point[0])<=180 && Math.abs(point[1])<=85;
    const index = decision.pointIndex;
    if (index != null && (!Number.isInteger(index) || index<0 || index>=route.length-1)) throw new Error('Invalid stage route position.');
    const match = valid && route.length>1 ? nearest(point,route,distances,index) : null;
    const problems = [];
    if (!match) problems.push('Place the stage pin.');
    if (match?.ambiguous) problems.push('Choose the route point at this crossing.');
    if (match?.distanceFromPathKm>0.5 && !decision.offRoute) problems.push('Confirm this as an off-route stop.');
    if (!decision.confirmed) problems.push('Confirm the stage connection.');
    if (problems.length) errors.push(`${stage.name || stage.id}: ${problems.join(' ')}`);
    return {stageId:stage.id, name:stage.name || stage.id, location:valid ? {latitude:point[1],longitude:point[0]} : null, ...match, confirmed:decision.confirmed===true, problems};
  });
  const ordered = [...stageLinks].filter(s=>s.accumulatedDistanceKm!=null).sort((a,b)=>a.accumulatedDistanceKm-b.accumulatedDistanceKm);
  const stages = ordered.map((link,i)=> {
    const original = stageRows.find(s=>s.id===link.stageId);
    const prior = ordered[i-1];
    const at = s => Math.min(route.length-1,s.pointIndex+(s.fraction>=0.5?1:0));
    return {...original, location:link.location, sequence:i+1, accumulatedDistanceKm:link.accumulatedDistanceKm,
      distanceFromPathKm:link.distanceFromPathKm, altitudeM:link.altitudeM, segmentLengthKm:link.accumulatedDistanceKm-(prior?.accumulatedDistanceKm || 0),
      elevationUpM:ascent[at(link)]-(prior ? ascent[at(prior)] : 0), elevationDownM:descent[at(link)]-(prior ? descent[at(prior)] : 0)};
  });
  if (!stageRows.length) errors.push('Add at least two stage records before publishing.');
  if (stageRows.length===1) errors.push('At least two stages are required.');
  const related = {excursions:[],detours:[]};
  function matchRelated(location,label,index) {
    if(!location || !Number.isFinite(location.longitude) || !Number.isFinite(location.latitude) || route.length<2) {errors.push(`${label}: missing connection location.`);return null;}
    if(index!=null && (!Number.isInteger(index) || index<0 || index>=route.length-1))throw new Error('Invalid related route connection index.');
    const result=nearest([location.longitude,location.latitude],route,distances,index);
    if(result.ambiguous)errors.push(`${label}: choose the main-route leg at this crossing.`);
    if(result.distanceFromPathKm>0.5)errors.push(`${label}: connection is more than 500 m from the trail. Update or exclude this related route.`);
    return result;
  }
  for(const type of ['excursions','detours']) for(const original of context[type] || []) {
    const key=`${type}:${original.id}`,decision=payload.relatedDecisions?.[key] || {};
    if(decision.excluded)continue;
    const {_chunks=[],...row}=original;
    if(_chunks.length!==row.chunkCount)errors.push(`${row.name || row.id}: incomplete related-route geometry.`);
    if(type==='excursions') {
      if(row.anchorType==='standalone'){related.excursions.push({...row,_chunks});continue;}
      const match=matchRelated(row.connectionLocation,row.name || row.id,decision.startPointIndex);
      if(match)related.excursions.push({...row,_chunks,mainTrailDistanceKm:match.accumulatedDistanceKm,mainTrailConnectionSegmentIndex:match.pointIndex,distanceFromTrailKm:match.distanceFromPathKm,trailConnectionLocation:{longitude:match.coordinates[0],latitude:match.coordinates[1]}});
    }else{
      const start=matchRelated(row.startConnection?.routeLocation,`${row.name || row.id} start`,decision.startPointIndex),end=matchRelated(row.endConnection?.routeLocation,`${row.name || row.id} end`,decision.endPointIndex);
      if(!start || !end)continue;
      const connect=(old,m)=>({...old,mainTrailDistanceKm:m.accumulatedDistanceKm,mainTrailSegmentIndex:m.pointIndex,distanceFromTrailKm:m.distanceFromPathKm,trailLocation:{longitude:m.coordinates[0],latitude:m.coordinates[1]}});
      const first=start.accumulatedDistanceKm<=end.accumulatedDistanceKm?start:end,last=first===start?end:start;
      const metric=(values,m)=>values[m.pointIndex]+(values[m.pointIndex+1]-values[m.pointIndex])*m.fraction;
      const up=metric(ascent,last)-metric(ascent,first),down=metric(descent,last)-metric(descent,first),replaced=last.accumulatedDistanceKm-first.accumulatedDistanceKm,minutes=Math.round(replaced*12+up/10);
      const affected=stages.filter(s=>s.accumulatedDistanceKm>=first.accumulatedDistanceKm && s.accumulatedDistanceKm<=last.accumulatedDistanceKm);
      const separations=[];
      for(const chunk of _chunks)for(let i=0;i<chunk.points.length;i+=row.pointStride || 5)separations.push(nearest([chunk.points[i+1],chunk.points[i]],route,distances).distanceFromPathKm);
      related.detours.push({...row,_chunks,startConnection:connect(row.startConnection,start),endConnection:connect(row.endConnection,end),replacedMainTrailDistanceKm:replaced,replacedElevationUpM:up,replacedElevationDownM:down,replacedEstimatedWalkingTimeMinutes:minutes,
        distanceDifferenceKm:row.routeDistanceKm-replaced,elevationUpDifferenceM:row.elevationUpM-up,elevationDownDifferenceM:row.elevationDownM-down,estimatedWalkingTimeDifferenceMinutes:row.estimatedWalkingTimeMinutes-minutes,
        averageDistanceFromTrailKm:separations.length?separations.reduce((a,b)=>a+b,0)/separations.length:0,maximumDistanceFromTrailKm:Math.max(0,...separations),affectedStageIds:affected.map(s=>s.id),affectedStageSequences:affected.map(s=>s.sequence),affectedStageNames:affected.map(s=>s.name)});
    }
  }
  if (warnings.length && !payload.changesReviewed) errors.push('Confirm the substantial route changes.');
  return {errors:[...new Set(errors)], warnings, stageLinks, stages, related, route, distances, totalDistanceKm, pointCount:route.length,
    contextHash:fingerprint(context), payloadHash:fingerprint(payload)};
}
export function normaliseStageEdits(value) {
  if (!Array.isArray(value) || value.length>500) throw new Error('Use at most 500 stages.');
  const seen=new Set();
  return value.map(stage=>{
    const id=requireId(stage.id);
    if(seen.has(id))throw new Error('Stage IDs must be unique.');
    seen.add(id);
    const {longitude,latitude}=stage.location || {};
    if(!Number.isFinite(longitude) || !Number.isFinite(latitude) || Math.abs(longitude)>180 || Math.abs(latitude)>85)throw new Error('Enter a valid stage location.');
    return {id,name:text(stage.name,160,true),description:text(stage.description || '',3000),location:{longitude,latitude}};
  });
}
export function revisionPayload(data) {
  const stageDecisions = {};
  for (const [id,value] of Object.entries(data.stageDecisions || {})) {
    requireId(id);
    stageDecisions[id] = {confirmed:value.confirmed===true, offRoute:value.offRoute===true};
    if (value.pointIndex != null) stageDecisions[id].pointIndex=value.pointIndex;
    if (value.location) stageDecisions[id].location={latitude:value.location.latitude,longitude:value.location.longitude};
  }
  const relatedDecisions={};
  for(const [key,value] of Object.entries(data.relatedDecisions || {})) {
    if(!/^(excursions|detours):[a-zA-Z0-9_-]{1,100}$/.test(key))throw new Error('Invalid related route.');
    relatedDecisions[key]={excluded:value.excluded===true,...(value.startPointIndex==null?{}:{startPointIndex:value.startPointIndex}),...(value.endPointIndex==null?{}:{endPointIndex:value.endPointIndex})};
  }
  return {...provenance(data),...(data.stageEdits===undefined?{}:{stageEdits:normaliseStageEdits(data.stageEdits)}),segments:normaliseSegments(data.segments), source:text(data.source || '',1000), attribution:text(data.attribution || '',1000),
    elevationSource:text(data.elevationSource || '',1000), stageDecisions, relatedDecisions,relatedRoutesReviewed:data.relatedRoutesReviewed===true, changesReviewed:data.changesReviewed===true};
}
export function buildRelease(validation) {
  if (validation.errors.length) throw new Error('Resolve validation errors before publishing.');
  const {route,distances,totalDistanceKm} = validation;
  const chunks = [];
  for (let start=0; start<route.length; start+=500) {
    const points = route.slice(start,start+500).flatMap((p,i)=>[p[1],p[0],p[2],distances[start+i],totalDistanceKm-distances[start+i]]);
    chunks.push({chunkIndex:chunks.length, startPointIndex:start, endPointIndex:start+points.length/5-1, points});
  }
  return {chunks, stages:validation.stages, metadata:{version:1, pointStride:5, pointFormat:['lat','lng','altitudeM','distanceKm','reverseDistanceKm'],
    pointCount:route.length,chunkCount:chunks.length,totalDistanceKm,maxAltitudeM:Math.max(...route.map(p=>p[2]))}};
}
