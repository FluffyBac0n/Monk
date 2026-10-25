'use client';
import {useEffect,useRef,useState} from 'react';
import type {Map as MapboxMap,GeoJSONSource} from 'mapbox-gl';
import {FitTrailButton} from '@/components/FitTrailButton';
import {preloadReportMap} from '@/lib/report-map-runtime';
import {loadTrailRoute} from '@/lib/trail-route';
import type {Segment,StageLink} from '@/lib/era';
import 'mapbox-gl/dist/mapbox-gl.css';
type Props={trailId:string;segments:Segment[];links:StageLink[];segmentIndex:number;pointIndex:number;onPoint:(p:number[])=>void;onSelect:(segment:number,point:number)=>void;editable:boolean;pin?:number[]};
export function EraRouteMap(props:Props) {
  const element=useRef<HTMLDivElement>(null),map=useRef<MapboxMap|null>(null),latest=useRef(props),published=useRef<number[][]>([]);
  latest.current=props;
  const [ready,setReady]=useState(false),[error,setError]=useState(''),[attempt,setAttempt]=useState(0);
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
        m.addLayer({id:'route-points',source:'points',type:'circle',minzoom:11,paint:{'circle-radius':['case',['get','selected'],7,3],'circle-color':['case',['get','selected'],'#17201b','#fff'],'circle-stroke-color':'#17201b','circle-stroke-width':1}});
        m.on('click',e=>{
          const found=m.queryRenderedFeatures(e.point,{layers:['route-points']})[0] as unknown as {properties?:{segment:number;point:number}} | undefined;
          if(found){latest.current.onSelect(Number(found.properties?.segment),Number(found.properties?.point));return;}
          if(latest.current.editable)latest.current.onPoint([e.lngLat.lng,e.lngLat.lat]);
        });
        setReady(true);
        void loadTrailRoute(props.trailId).then(coords=>{if(alive){published.current=coords;(m.getSource('published') as GeoJSONSource)?.setData({type:'Feature',properties:{},geometry:{type:'LineString',coordinates:coords}});if(!latest.current.segments.length){const bounds=new gl.LngLatBounds();coords.forEach(p=>bounds.extend(p));m.fitBounds(bounds,{padding:45,maxZoom:15});}}},()=>{});
      });
    }catch{if(alive)setError('Map unavailable. Retry the map.');}})();
    return()=>{alive=false;clearTimeout(timer);map.current?.remove();map.current=null;};
  },[props.trailId,attempt]);
  useEffect(()=>{
    if(!ready || !map.current)return;
    const m=map.current;
    (m.getSource('draft') as GeoJSONSource).setData({type:'FeatureCollection',features:props.segments.map(s=>({type:'Feature',properties:{kind:s.kind},geometry:{type:'LineString',coordinates:s.coordinates}}))});
    // Keep the whole line, but limit clickable point features for very large imports.
    (m.getSource('points') as GeoJSONSource).setData({type:'FeatureCollection',features:props.segments.flatMap((s,si)=>s.coordinates.flatMap((p,pi)=>pi%Math.max(1,Math.ceil(s.coordinates.length/5000))===0 || (si===props.segmentIndex && pi===props.pointIndex)?[{type:'Feature' as const,properties:{segment:si,point:pi,selected:si===props.segmentIndex && pi===props.pointIndex},geometry:{type:'Point' as const,coordinates:p}}]:[]))});
    (m.getSource('links') as GeoJSONSource).setData({type:'FeatureCollection',features:props.links.flatMap(s=>s.location && s.coordinates?[{type:'Feature' as const,properties:{},geometry:{type:'LineString' as const,coordinates:[[s.location.longitude,s.location.latitude],s.coordinates]}}]:[])});
    const pins=[...props.links.flatMap(s=>s.location?[[s.location.longitude,s.location.latitude]]:[]),...(props.pin?[props.pin]:[])];
    (m.getSource('pins') as GeoJSONSource).setData({type:'FeatureCollection',features:pins.map(p=>({type:'Feature',properties:{},geometry:{type:'Point',coordinates:p}}))});
  },[ready,props.segments,props.links,props.segmentIndex,props.pointIndex,props.pin]);
  function fit(){const points=props.segments.length?props.segments.flatMap(s=>s.coordinates):published.current;if(!points.length || !map.current)return;const lng=points.map(p=>p[0]),lat=points.map(p=>p[1]);map.current.fitBounds([[Math.min(...lng),Math.min(...lat)],[Math.max(...lng),Math.max(...lat)]],{padding:45,maxZoom:15});}
  useEffect(()=>{if(ready)fit();},[ready,props.segments.length]); // Preserve camera while moving individual points.
  return <section className="report-map-panel"><div className="report-map-canvas"><div ref={element} className="trail-report-map" aria-label="Published and proposed trail map"/><FitTrailButton disabled={!ready || !!error} onClick={fit}/></div><div className="report-map-legend report-map-legend-bottom" aria-label="Map legend"><span><i className="report-map-line" aria-hidden="true"/>Published</span><span><i className="report-map-line era-map-draft" aria-hidden="true"/>Draft</span><span><i className="report-map-line era-map-alternative" aria-hidden="true"/>Alternative</span></div>{error && <p className="notice error" role="alert">{error} <button type="button" className="button button-secondary" onClick={()=>setAttempt(a=>a+1)}>Retry map</button></p>}{!ready && !error && <p role="status">Loading map…</p>}</section>;
}
