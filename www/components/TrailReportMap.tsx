'use client';
import {useEffect, useRef, useState} from 'react';
import type {Map as MapboxMap} from 'mapbox-gl';
import {reportStatuses, type TrailReport} from '@/lib/trail-reports';
import {reportStatusLabels} from '@/components/ReportReview';
import {FitTrailButton} from '@/components/FitTrailButton';
import {ReportStatusIcon} from '@/components/ReportStatusIcon';
import {createIncidentMarkers} from '@/lib/incident-map-markers';
import {loadTrailRoute} from '@/lib/trail-route';
import {preloadReportMap} from '@/lib/report-map-runtime';
import 'mapbox-gl/dist/mapbox-gl.css';

type Props = {visible: boolean; trailId: string; trailName: string; reports: TrailReport[]; selectedId: string; onSelect: (id: string) => void; onSettled?: () => void};
export function TrailReportMap({visible, trailId, trailName, reports, selectedId, onSelect, onSettled}: Props) {
  const element = useRef<HTMLDivElement>(null), map = useRef<MapboxMap | null>(null);
  const markers = useRef<ReturnType<typeof createIncidentMarkers> | null>(null);
  const latest = useRef({reports, selectedId, onSelect, onSettled});
  latest.current = {reports, selectedId, onSelect, onSettled};
  const route = useRef<[number, number][]>([]), fitted = useRef(false);
  const [ready, setReady] = useState(false), [error, setError] = useState(''), [routeNotice, setRouteNotice] = useState('');
  const [attempt, setAttempt] = useState(0);
  const userMoved = useRef(false);
  const [routeLoading, setRouteLoading] = useState(true);
  const fit = useRef<() => void>(() => {});

  useEffect(() => {
    let cancelled = false, settled = false;
    const finish = () => {
      if (cancelled || settled) return;
      settled = true; window.clearTimeout(timeout); latest.current.onSettled?.();
    };
    userMoved.current = false; setRouteLoading(true);
    const timeout = window.setTimeout(() => {if (!cancelled) {setError('The map is taking too long to load. Check your connection and retry.'); finish();}}, 30000);
    setReady(false); setError(''); setRouteNotice(''); fitted.current = false; route.current = [];
    const routeResult = loadTrailRoute(trailId).then(coordinates => ({coordinates, failed: false}), () => ({coordinates: [] as [number, number][], failed: true}));
    void (async () => {
      try {
        const {gl, accessToken} = await preloadReportMap();
        if (cancelled || !element.current) return;
        const instance = new gl.Map({container: element.current, accessToken, scrollZoom: false, cooperativeGestures: true,
          style: 'mapbox://styles/mapbox/outdoors-v12', center: [33, 34.9], zoom: 8, attributionControl: true});
        map.current = instance;
        instance.addControl(new gl.NavigationControl({showCompass: false}), 'top-right');
        instance.on('movestart', event => {if (event.originalEvent) userMoved.current = true;});
        instance.on('error', () => {
          if (cancelled) return;
          if (!instance.isStyleLoaded()) {setError('The map background could not be loaded. Check your connection and retry.'); finish();}
        });
        fit.current = () => {
          const points = [...route.current, ...latest.current.reports.map(r => [r.longitude, r.latitude] as [number, number])];
          if (!points.length) return;
          const bounds = new gl.LngLatBounds();
          points.forEach(point => bounds.extend(point));
          instance.fitBounds(bounds, {padding: 56, maxZoom: 15, duration: settled ? 400 : 0});
          fitted.current = true;
        };
        instance.on('load', () => {
          if (cancelled) return;
          setError(''); setReady(true);
          void routeResult.then(result => {
            if (cancelled) return;
            setRouteLoading(false); route.current = result.coordinates;
            if (result.failed) {setRouteNotice('The trail line could not be loaded. Report locations are still shown.'); fit.current(); finish(); return;}
            instance.addSource('trail', {type: 'geojson', data: {type: 'Feature', properties: {}, geometry: {type: 'LineString', coordinates: result.coordinates}}});
            instance.addLayer({id: 'trail-outline', type: 'line', source: 'trail', layout: {'line-join': 'round', 'line-cap': 'round'}, paint: {'line-color': '#ffffff', 'line-width': 7}});
            instance.addLayer({id: 'trail-line', type: 'line', source: 'trail', layout: {'line-join': 'round', 'line-cap': 'round'}, paint: {'line-color': '#2d5dd3', 'line-width': 4}});
            if (!userMoved.current && !latest.current.selectedId) fit.current();
            // Reveal only after the trail source, viewport and background have rendered.
            instance.once('idle', finish);
            instance.triggerRepaint();
          }).catch(() => {
            if (!cancelled) {setRouteLoading(false); setRouteNotice('The trail line could not be loaded. Report locations are still shown.'); finish();}
          });
        });
      } catch {
        if (!cancelled) {setError('The map could not be loaded. Check your connection and retry.'); finish();}
      }
    })();
    return () => {
      cancelled = true; window.clearTimeout(timeout);
      markers.current?.destroy(); markers.current = null;
      map.current?.remove(); map.current = null; fit.current = () => {};
    };
  }, [trailId, attempt]);

  useEffect(() => {
    if (!ready || !map.current) return;
    const instance = map.current;
    let cancelled = false;
    let controller: ReturnType<typeof createIncidentMarkers> | null = null;
    void import('mapbox-gl').then(({default: gl}) => {
      if (cancelled) return;
      controller = createIncidentMarkers(instance, gl, id => latest.current.onSelect(id));
      markers.current = controller;
      controller.update(latest.current.reports);
      if (!fitted.current && latest.current.reports.length) fit.current();
      controller.select(latest.current.selectedId);
    });
    return () => {cancelled = true; controller?.destroy(); if (markers.current === controller) markers.current = null;};
  }, [ready]);

  useEffect(() => {
    markers.current?.update(reports);
    if (ready && !fitted.current && reports.length) fit.current();
  }, [ready, reports]);

  useEffect(() => {markers.current?.select(selectedId);}, [ready, selectedId]);

  useEffect(() => {
    if (!visible || !map.current) return;
    const frame = requestAnimationFrame(() => map.current?.resize());
    return () => cancelAnimationFrame(frame);
  }, [visible, ready]);

  return <section className={`report-map-panel ${visible ? '' : 'is-preloading'}`} aria-hidden={!visible} inert={!visible} aria-label={`${trailName} report map`}>
    <div className="report-map-canvas"><div className="trail-report-map" ref={element} aria-label="Map of reported trail problems" /><FitTrailButton disabled={!ready || !!error} onClick={() => fit.current()}/></div>
    <div className="report-map-legend report-map-legend-bottom" aria-label="Map legend"><span><i className="report-map-line" aria-hidden="true" />{trailName}</span>{reportStatuses.filter(status=>reports.some(report=>report.status===status)).map(status=><span key={status}><ReportStatusIcon status={status}/>{reportStatusLabels[status]}</span>)}</div>
    {!ready && !error && <p className="report-map-message" role="status">Loading trail map…</p>}
    {error && <div className="report-map-message" role="alert"><p>{error}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Retry map</button></div>}
    {ready && routeLoading && <p className="report-map-caption" role="status">Loading the trail line… You can already explore report locations.</p>}
    {routeNotice && <div className="report-map-caption" role="status"><p>{routeNotice}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Retry trail</button></div>}
  </section>;
}
