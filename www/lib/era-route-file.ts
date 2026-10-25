import type {Segment} from './era';

export type RouteImport = {segments:Segment[]; source:string; attribution:string; elevationSource:string; geojson:string};
const children = (element:Element, name:string) => Array.from(element.children).filter(child => child.localName === name);
const child = (element:Element, name:string) => children(element,name)[0];
const text = (element:Element | undefined) => element?.textContent?.trim() || '';

export function validateRouteSegments(segments:Segment[]) {
  if (!segments.length) throw new Error('This file has no track or route points.');
  if (segments.length>100) throw new Error('Use a route with no more than 100 sections and 100,000 points.');
  let pointCount=0;
  for (const segment of segments) {
    if (!segment || !Array.isArray(segment.coordinates) || segment.coordinates.length<2) throw new Error('Each route section needs at least two points.');
    pointCount+=segment.coordinates.length;
    if(pointCount>100000)throw new Error('Use a route with no more than 100 sections and 100,000 points.');
    for (const point of segment.coordinates) {
      if (!Array.isArray(point) || point.length<2 || point.length>3 || !point.every(Number.isFinite) || Math.abs(point[0])>180 || Math.abs(point[1])>85 || (point.length===3 && (point[2]<-500 || point[2]>9000))) throw new Error('The file contains invalid coordinates or elevations.');
    }
  }
  return segments;
}

export function parseRouteFile(source:string, filename:string):RouteImport {
  let segments:Segment[]=[], attribution='', elevationSource='', routeSource=filename;
  if (/\.gpx$/i.test(filename) || source.trimStart().startsWith('<')) {
    if (/<!DOCTYPE|<!ENTITY/i.test(source)) throw new Error('Use a GPX file without document type or entity declarations.');
    const document=new DOMParser().parseFromString(source,'application/xml');
    const root=document.documentElement;
    if (!root || root.localName!=='gpx' || Array.from(document.getElementsByTagName('*')).some(node=>node.localName==='parsererror')) throw new Error('This GPX file could not be read. Check the file and try again.');
    const coordinate=(point:Element) => {
      const longitude=point.getAttribute('lon'),latitude=point.getAttribute('lat'),elevation=child(point,'ele');
      if (!longitude?.trim() || !latitude?.trim()) throw new Error('A GPX point is missing its latitude or longitude.');
      const numeric=/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/;
      if(!numeric.test(longitude.trim()) || !numeric.test(latitude.trim()) || (elevation && !numeric.test(text(elevation))))throw new Error('The GPX file contains a non-numeric coordinate or elevation.');
      const values=[Number(longitude),Number(latitude)];
      if (elevation) {if (!text(elevation)) throw new Error('A GPX elevation is empty.'); values.push(Number(text(elevation)));}
      return values;
    };
    const tracks=children(root,'trk').flatMap(track=>children(track,'trkseg'));
    segments=tracks.map(section=>({kind:'main',coordinates:children(section,'trkpt').map(coordinate)}));
    if (!segments.length) segments=children(root,'rte').map(route=>({kind:'main',coordinates:children(route,'rtept').map(coordinate)}));
    const metadata=child(root,'metadata') || root;
    const copyright=child(metadata,'copyright'),author=child(metadata,'author');
    attribution=[copyright?.getAttribute('author') || (author ? text(child(author,'name')) || text(author) : ''),copyright ? text(child(copyright,'license')) : ''].filter(Boolean).join(' · ');
    routeSource=[text(child(metadata,'name')),filename].filter(Boolean).join(' · ');
    elevationSource=segments.some(section=>section.coordinates.some(point=>point.length===3)) ? `GPX file: ${filename}` : '';
  } else {
    let json:unknown;
    try {json=JSON.parse(source);} catch {throw new Error('Choose a GPX or GeoJSON route file.');}
    const visit=(value:unknown) => {
      if (!value || typeof value!=='object') throw new Error('Invalid GeoJSON route.');
      const v=value as {type:string;features?:unknown[];geometry?:unknown;geometries?:unknown[];coordinates?:number[][] | number[][][]};
      if (v.type==='FeatureCollection' && Array.isArray(v.features)) v.features.forEach(visit);
      else if (v.type==='Feature') visit(v.geometry);
      else if (v.type==='GeometryCollection' && Array.isArray(v.geometries)) v.geometries.forEach(visit);
      else if (v.type==='LineString' && Array.isArray(v.coordinates)) segments.push({kind:'main',coordinates:v.coordinates as number[][]});
      else if (v.type==='MultiLineString' && Array.isArray(v.coordinates)) v.coordinates.forEach(coordinates=>segments.push({kind:'main',coordinates:coordinates as number[][]}));
      else throw new Error('The route file must contain lines, not markers or areas.');
    };
    visit(json);
    validateRouteSegments(segments);
    elevationSource=segments.some(section=>section.coordinates.some(point=>point.length===3)) ? `GeoJSON file: ${filename}` : '';
  }
  validateRouteSegments(segments);
  return {segments,source:routeSource.slice(0,1000),attribution:attribution.slice(0,1000),elevationSource,geojson:JSON.stringify({type:'FeatureCollection',features:segments.map(segment=>({type:'Feature',properties:{},geometry:{type:'LineString',coordinates:segment.coordinates}}))})};
}

export function routeSummary(segments:Segment[]) {
  let distanceKm=0,pointCount=0;
  const rad=(value:number)=>value*Math.PI/180;
  for (const segment of segments) {
    pointCount+=segment.coordinates.length;
    for (let i=1;i<segment.coordinates.length;i++) {
      const a=segment.coordinates[i-1],b=segment.coordinates[i];
      const h=Math.sin(rad(b[1]-a[1])/2)**2+Math.cos(rad(a[1]))*Math.cos(rad(b[1]))*Math.sin(rad(b[0]-a[0])/2)**2;
      distanceKm+=6371*2*Math.atan2(Math.sqrt(h),Math.sqrt(Math.max(0,1-h)));
    }
  }
  return {distanceKm,pointCount};
}
