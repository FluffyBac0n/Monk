'use client';
import {useEffect, useRef} from 'react';
import type {TrailReport} from '@/lib/trail-reports';
import 'leaflet/dist/leaflet.css';
export function TrailReportMap({reports, onSelect}: {reports: TrailReport[]; onSelect: (id: string) => void}) {
  const element = useRef<HTMLDivElement>(null);
  useEffect(() => {
    let cancelled = false;
    let map: import('leaflet').Map | undefined;
    void import('leaflet').then(L => {
      if (cancelled || !element.current) return;
      map = L.map(element.current).setView([34.9, 33], 9);
      L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {maxZoom: 19, attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'}).addTo(map);
      for (const report of reports) {
        const text = document.createElement('span'); text.textContent = report.description;
        L.circleMarker([report.latitude, report.longitude], {radius: 8, color: report.priority === 'urgent' ? '#b53425' : '#d56825', fillOpacity: .9})
          .addTo(map).bindTooltip(text).on('click', () => onSelect(report.id));
      }
      if (reports.length) map.fitBounds(reports.map(r => [r.latitude, r.longitude] as [number, number]), {padding: [35, 35], maxZoom: 15});
    });
    return () => { cancelled = true; map?.remove(); };
  }, [reports, onSelect]);
  return <div className="trail-report-map" ref={element} aria-label="Map of reported trail problems" />;
}
