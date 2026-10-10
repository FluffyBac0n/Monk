'use client';
import {useEffect, useRef, useState} from 'react';
import type {Map as MapboxMap, Marker} from 'mapbox-gl';
import {reportCategories, type TrailReport} from '@/lib/trail-reports';
import {loadTrailRoute} from '@/lib/trail-route';
import {preloadReportMap} from '@/lib/report-map-runtime';
import 'mapbox-gl/dist/mapbox-gl.css';

const warningIcon = '<svg viewBox="0 0 48 48" aria-hidden="true"><path d="M21 6a3.5 3.5 0 0 1 6 0l18 31a3.5 3.5 0 0 1-3 5H6a3.5 3.5 0 0 1-3-5Z"/><text x="24" y="34" text-anchor="middle">!</text></svg>';
type Props = {visible: boolean; trailId: string; trailName: string; reports: TrailReport[]; selectedId: string; onSelect: (id: string) => void};
export function TrailReportMap({visible, trailId, trailName, reports, selectedId, onSelect}: Props) {
  const element = useRef<HTMLDivElement>(null), map = useRef<MapboxMap | null>(null);
  const markers = useRef(new Map<string, Marker>());
  const latest = useRef({reports, selectedId, onSelect});
  latest.current = {reports, selectedId, onSelect};
  const route = useRef<[number, number][]>([]), fitted = useRef(false);
  const [ready, setReady] = useState(false), [error, setError] = useState(''), [routeNotice, setRouteNotice] = useState('');
  const [attempt, setAttempt] = useState(0);
  const userMoved = useRef(false);
  const [routeLoading, setRouteLoading] = useState(true);
  const fit = useRef<() => void>(() => {});

  useEffect(() => {
    let cancelled = false;
    userMoved.current = false; setRouteLoading(true);
    const timeout = window.setTimeout(() => {if (!cancelled) setError('The map is taking too long to load. Check your connection and retry.');}, 30000);
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
          if (!instance.isStyleLoaded()) setError('The map background could not be loaded. Check your connection and retry.');
        });
        fit.current = () => {
          const points = [...route.current, ...latest.current.reports.map(r => [r.longitude, r.latitude] as [number, number])];
          if (!points.length) return;
          const bounds = new gl.LngLatBounds();
          points.forEach(point => bounds.extend(point));
          instance.fitBounds(bounds, {padding: 56, maxZoom: 15, duration: 400});
          fitted.current = true;
        };
        instance.on('load', () => {
          if (cancelled) return;
          window.clearTimeout(timeout); setError(''); setReady(true);
          fit.current();
          void routeResult.then(result => {
            if (cancelled) return;
            setRouteLoading(false); route.current = result.coordinates;
            if (result.failed) {setRouteNotice('The trail line could not be loaded. Report locations are still shown.'); return;}
            instance.addSource('trail', {type: 'geojson', data: {type: 'Feature', properties: {}, geometry: {type: 'LineString', coordinates: result.coordinates}}});
            instance.addLayer({id: 'trail-outline', type: 'line', source: 'trail', layout: {'line-join': 'round', 'line-cap': 'round'}, paint: {'line-color': '#ffffff', 'line-width': 7}});
            instance.addLayer({id: 'trail-line', type: 'line', source: 'trail', layout: {'line-join': 'round', 'line-cap': 'round'}, paint: {'line-color': '#2d5dd3', 'line-width': 4}});
            if (!userMoved.current && !latest.current.selectedId) fit.current();
          });
        });
      } catch {
        if (!cancelled) setError('The map could not be loaded. Check your connection and retry.');
      }
    })();
    return () => {
      cancelled = true; window.clearTimeout(timeout);
      markers.current.forEach(marker => marker.remove()); markers.current.clear();
      map.current?.remove(); map.current = null; fit.current = () => {};
    };
  }, [trailId, attempt]);

  useEffect(() => {
    if (!ready || !map.current) return;
    const instance = map.current;
    let cancelled = false;
    void import('mapbox-gl').then(({default: gl}) => {
      if (cancelled) return;
      const ids = new Set(reports.map(report => report.id));
      markers.current.forEach((marker, id) => {if (!ids.has(id)) {marker.remove(); markers.current.delete(id);}});
      for (const report of reports) {
        let marker = markers.current.get(report.id);
        if (!marker) {
          const button = document.createElement('button');
          button.type = 'button'; button.className = 'report-map-marker'; button.innerHTML = warningIcon;
          button.setAttribute('aria-controls', 'selected-trail-report');
          button.addEventListener('click', event => {event.stopPropagation(); latest.current.onSelect(report.id);});
          marker = new gl.Marker({element: button, anchor: 'center'}).setLngLat([report.longitude, report.latitude]).addTo(instance);
          button.setAttribute('role', 'button');
          markers.current.set(report.id, marker);
        }
        marker.setLngLat([report.longitude, report.latitude]);
        const button = marker.getElement();
        button.setAttribute('aria-label', `Open report: ${reportCategories[report.category] || report.category} — ${report.description}`);
        button.title = `${reportCategories[report.category] || report.category}: ${report.description}`;
        button.classList.toggle('is-selected', report.id === selectedId);
        button.setAttribute('aria-pressed', String(report.id === selectedId));
      }
      if (!fitted.current && reports.length) fit.current();
    });
    return () => {cancelled = true;};
  }, [ready, reports, selectedId]);

  useEffect(() => {
    if (!ready || !map.current || !selectedId) return;
    const report = latest.current.reports.find(r => r.id === selectedId);
    if (!report) return;
    // Preserve the user's zoom; move only when the selected issue is near/outside the map edge.
    const point = map.current.project([report.longitude, report.latitude]);
    const {width, height} = map.current.getContainer().getBoundingClientRect();
    if (point.x < 55 || point.y < 55 || point.x > width - 55 || point.y > height - 55) {
      map.current.easeTo({center: [report.longitude, report.latitude], duration: 400});
    }
  }, [ready, selectedId]);

  useEffect(() => {
    if (!visible || !map.current) return;
    const frame = requestAnimationFrame(() => map.current?.resize());
    return () => cancelAnimationFrame(frame);
  }, [visible, ready]);

  const chosen = reports.find(r => r.id === selectedId);
  return <section className={`report-map-panel ${visible ? '' : 'is-preloading'}`} aria-hidden={!visible} inert={!visible} aria-label={`${trailName} report map`}>
    <div className="report-map-toolbar"><div className="report-map-legend"><span><i className="report-map-line" />{trailName}</span><span><i className="report-map-warning" aria-hidden="true">▲</i>Reports</span></div><button className="button button-secondary" disabled={!ready || !!error} onClick={() => fit.current()}>Fit trail</button></div>
    <div className="trail-report-map" ref={element} aria-label="Map of reported trail problems" />
    {!ready && !error && <p className="report-map-message" role="status">Loading trail map…</p>}
    {error && <div className="report-map-message" role="alert"><p>{error}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Retry map</button></div>}
    {ready && routeLoading && <p className="report-map-caption" role="status">Loading the trail line… You can already explore report locations.</p>}
    {routeNotice && <div className="report-map-caption" role="status"><p>{routeNotice}</p><button className="button button-secondary" onClick={() => setAttempt(n => n + 1)}>Retry trail</button></div>}
    <p className="report-map-caption" role="status">{chosen ? `Selected: ${reportCategories[chosen.category] || chosen.category} · ${chosen.description}` : 'Select a warning triangle or a report to see its details.'}</p>
  </section>;
}
