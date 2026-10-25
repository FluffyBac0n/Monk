'use client';
import {useEffect,useRef,useState} from 'react';
import type {Map as MapboxMap,GeoJSONSource,Marker} from 'mapbox-gl';
import {FitTrailButton} from '@/components/FitTrailButton';
import {preloadReportMap} from '@/lib/report-map-runtime';
import {loadTrailRoute} from '@/lib/trail-route';
import type {Segment,StageLink} from '@/lib/era';
import 'mapbox-gl/dist/mapbox-gl.css';
type Props={trailId:string;segments:Segment[];links:StageLink[];segmentIndex:number;pointIndex:number;onPoint:(p:number[])=>void;onSelect:(segment:number,point:number)=>void;editable:boolean;pin?:number[];editing?:boolean;draggable?:boolean;current?:boolean;fitKey?:number;onMove?:(p:number[])=>void};
export function EraRouteMap(props:Props) {
  const element=useRef<HTMLDivElement>(null),map=useRef<MapboxMap|null>(null),latest=useRef(props),published=useRef<number[][]>([]);
  latest.current=props;
  const [ready,setReady]=useState(false),[error,setError]=useState(''),[attempt,setAttempt]=useState(0);
  const selectedMarker=useRef<Marker|null>(null);
  useEffect(()=>{
    let alive=true;
    setReady(false);setError('');published.current=[];
    const timer=setTimeout(()=>{if(alive)setError('Map loading timed out. Retry the map.');},30000);
    void (async()=>{try{
      const {gl,accessToken}=await preloadReportMap();if(!alive || !element.current)return;
      const m=new gl.Map({container:element.current,accessToken,style:'mapbox://styles/mapbox/outdoors-v12',center:[33,34.9],zoom:8,scrollZoom:false});map.current=m;
      m.addControl(new gl.NavigationControl({showCompass:false}));
      m.on('error',()=>{if(alive && !m.isStyleLoaded())setError('The map background could not load.');});
      m.on('load',()=>{
        if(!alive)return;clearTimeout(timer);setError('');
        for(const id of ['published','draft','points','links','pins'])m.addSource(id,{type:'geojson',data:{type:'FeatureCollection',features:[]}});
        m.addLayer({id:'published-line',source:'published',type:'line',paint:{'line-color':'#2d5dd3','line-width':4,'line-opacity':0.55}});
        m.addLayer({id:'draft-line',source:'draft',type:'line',paint:{'line-color':['case',['==',['get','kind'],'alternative'],'#898275','#d08c16'],'line-width':4}});
        m.addLayer({id:'stage-links',source:'links',type:'line',paint:{'line-color':'#525a52','line-width':2,'line-dasharray':[2,2]}});
        m.addLayer({id:'stage-pins',source:'pins',type:'circle',paint:{'circle-radius':7,'circle-color':'#17201b','circle-stroke-width':2,'circle-stroke-color':'#f2c94c'}});
        m.addLayer({id:'route-points',source:'points',type:'circle',minzoom:11,paint:{'circle-radius':['case',['get','selected'],7,4],'circle-color':['case',['get','selected'],'#17201b','#fff'],'circle-stroke-color':'#17201b','circle-stroke-width':1}});
        const handle=document.createElement('div');
        handle.className='era-selected-point';handle.setAttribute('aria-label','Selected trail point');handle.setAttribute('role','img');handle.title='Drag to move this point';
        selectedMarker.current=new gl.Marker({element:handle,draggable:false});
        selectedMarker.current.on('dragend',()=>{const position=selectedMarker.current?.getLngLat();if(position && latest.current.draggable)latest.current.onMove?.([position.lng,position.lat]);});
        m.on('click',e=>{
          if(latest.current.editing===false)return;
          if(latest.current.editable){latest.current.onPoint([e.lngLat.lng,e.lngLat.lat]);return;}
          const found=m.queryRenderedFeatures(e.point,{layers:['route-points']})[0] as unknown as {properties?:{segment:number;point:number}} | undefined;
          if(found){latest.current.onSelect(Number(found.properties?.segment),Number(found.properties?.point));return;}
          // Pick from the full route, even when display points are thinned at this zoom.
          if(latest.current.editing){let best=144,selection:null|[number,number]=null;latest.current.segments.forEach((section,si)=>section.coordinates.forEach((point,pi)=>{const pixel=m.project([point[0],point[1]]),distance=(pixel.x-e.point.x)**2+(pixel.y-e.point.y)**2;if(distance<best){best=distance;selection=[si,pi];}}));if(selection)latest.current.onSelect(selection[0],selection[1]);}
        });
        setReady(true);
        void loadTrailRoute(props.trailId).then(coords=>{if(alive){published.current=coords;(m.getSource('published') as GeoJSONSource)?.setData({type:'Feature',properties:{},geometry:{type:'LineString',coordinates:coords}});if(!latest.current.segments.length){const bounds=new gl.LngLatBounds();coords.forEach(p=>bounds.extend(p));m.fitBounds(bounds,{padding:45,maxZoom:15});}}},()=>{});
      });
    }catch{if(alive)setError('Map unavailable. Retry the map.');}})();
    return()=>{alive=false;clearTimeout(timer);selectedMarker.current?.remove();selectedMarker.current=null;map.current?.remove();map.current=null;};
  },[props.trailId,attempt]);
  useEffect(()=>{
    if(!ready || !map.current)return;
    const m=map.current;
    (m.getSource('draft') as GeoJSONSource).setData({type:'FeatureCollection',features:props.segments.map(s=>({type:'Feature',properties:{kind:s.kind},geometry:{type:'LineString',coordinates:s.coordinates}}))});
    m.setPaintProperty('draft-line','line-color',props.current?'#2d5dd3':['case',['==',['get','kind'],'alternative'],'#898275','#d08c16']);
    m.setLayoutProperty('published-line','visibility',props.current && props.segments.length?'none':'visible');
    m.setLayoutProperty('route-points','visibility',props.editing===false?'none':'visible');
    // Keep the whole line, but limit clickable point features for very large imports.
    (m.getSource('points') as GeoJSONSource).setData({type:'FeatureCollection',features:props.segments.flatMap((s,si)=>s.coordinates.flatMap((p,pi)=>pi%Math.max(1,Math.ceil(s.coordinates.length/5000))===0 || (si===props.segmentIndex && pi===props.pointIndex)?[{type:'Feature' as const,properties:{segment:si,point:pi,selected:si===props.segmentIndex && pi===props.pointIndex},geometry:{type:'Point' as const,coordinates:p}}]:[]))});
    (m.getSource('links') as GeoJSONSource).setData({type:'FeatureCollection',features:props.links.flatMap(s=>s.location && s.coordinates?[{type:'Feature' as const,properties:{},geometry:{type:'LineString' as const,coordinates:[[s.location.longitude,s.location.latitude],s.coordinates]}}]:[])});
    const pins=[...props.links.flatMap(s=>s.location?[[s.location.longitude,s.location.latitude]]:[]),...(props.pin?[props.pin]:[])];
    (m.getSource('pins') as GeoJSONSource).setData({type:'FeatureCollection',features:pins.map(p=>({type:'Feature',properties:{},geometry:{type:'Point',coordinates:p}}))});
    const selected=props.segments[props.segmentIndex]?.coordinates[props.pointIndex];
    if(props.editing && selected && selectedMarker.current){selectedMarker.current.setLngLat([selected[0],selected[1]]).setDraggable(!!props.draggable).addTo(m);selectedMarker.current.getElement().classList.toggle('is-draggable',!!props.draggable);}else selectedMarker.current?.remove();
  },[ready,props.segments,props.links,props.segmentIndex,props.pointIndex,props.pin,props.editing,props.draggable,props.current]);
  function fit(){const points=props.segments.length?props.segments.flatMap(s=>s.coordinates):published.current;if(!points.length || !map.current)return;let west=Infinity,south=Infinity,east=-Infinity,north=-Infinity;for(const point of points){west=Math.min(west,point[0]);east=Math.max(east,point[0]);south=Math.min(south,point[1]);north=Math.max(north,point[1]);}map.current.fitBounds([[west,south],[east,north]],{padding:45,maxZoom:15});}
  useEffect(()=>{if(ready)fit();},[ready,props.fitKey ?? props.segments.length]); // Preserve camera while moving individual points.
  useEffect(()=>{const selected=props.segments[props.segmentIndex]?.coordinates[props.pointIndex],m=map.current;if(!ready || !props.editing || !selected || !m)return;const pixel=m.project([selected[0],selected[1]]),bounds=m.getContainer().getBoundingClientRect();if(pixel.x<20 || pixel.y<20 || pixel.x>bounds.width-20 || pixel.y>bounds.height-20)m.easeTo({center:[selected[0],selected[1]],duration:300});},[ready,props.editing,props.segmentIndex,props.pointIndex]);

  return <section className="report-map-panel"><div className="report-map-canvas"><div ref={element} className="trail-report-map" aria-label="Published and proposed trail map"/><FitTrailButton disabled={!ready || !!error} onClick={fit}/></div><div className="report-map-legend report-map-legend-bottom" aria-label="Map legend"><span><i className="report-map-line" aria-hidden="true"/>Current trail</span>{!props.current && props.segments.length>0 && <span><i className="report-map-line era-map-draft" aria-hidden="true"/>Changes</span>}{props.segments.some(section=>section.kind==='alternative') && <span><i className="report-map-line era-map-alternative" aria-hidden="true"/>Alternative</span>}</div>{error && <p className="notice error" role="alert">{error} <button type="button" className="button button-secondary" onClick={()=>setAttempt(a=>a+1)}>Retry map</button></p>}{!ready && !error && <p role="status">Loading map…</p>}</section>;
}
