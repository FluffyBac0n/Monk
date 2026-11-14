import type {GeoJSONSource, Map as MapboxMap, Marker} from 'mapbox-gl';
import {reportCategories, reportStatuses, type TrailReport} from './trail-reports';
import {reportStatusLabels} from '../components/ReportReview';
import {reportStatusMarker} from './report-status-symbols';

const sourceId = 'incident-points';
const clusterMaxZoom = 15;
type IncidentFeature = {geometry: {type: string; coordinates: number[]}; properties: {revision: number; cluster?: boolean; cluster_id: number; point_count: number; reportId: string}};

// Keep accessible HTML status buttons while Mapbox handles spatial clustering.
export function createIncidentMarkers(map: MapboxMap, gl: {Marker: typeof Marker}, onSelect: (id: string) => void) {
  const markers = new Map<string, Marker>();
  let reports = new Map<string, TrailReport>(), selectedId = '', revision = 0, disposed = false;
  map.addSource(sourceId, {type: 'geojson', data: {type: 'FeatureCollection', features: []},
    cluster: true, clusterRadius: 50, clusterMaxZoom,
    clusterProperties: {revision: ['max', ['get', 'revision']]}});
  // A transparent layer keeps source tiles active; HTML buttons provide the visuals.
  map.addLayer({id: sourceId, type: 'circle', source: sourceId, paint: {'circle-radius': 0, 'circle-opacity': 0}});
  const source = map.getSource(sourceId) as GeoJSONSource;
  const clear = () => {markers.forEach(marker => marker.remove()); markers.clear();};

  function render() {
    if (disposed || !map.isSourceLoaded(sourceId)) return;
    const visible = new Set<string>();
    for (const feature of map.querySourceFeatures(sourceId) as unknown as IncidentFeature[]) {
      if (feature.geometry.type !== 'Point' || feature.properties?.revision !== revision) continue;
      const coordinates = feature.geometry.coordinates as [number, number];
      if (!map.getBounds()?.contains(coordinates)) continue;
      const properties = feature.properties;
      const cluster = Boolean(properties.cluster);
      const report = cluster ? undefined : reports.get(properties.reportId);
      if (!cluster && !report) continue;
      const key = cluster ? `cluster:${properties.cluster_id}` : `report:${report!.id}`;
      if (visible.has(key)) continue; // A feature may occur in adjacent tiles.
      visible.add(key);
      let marker = markers.get(key);
      if (!marker) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = cluster ? 'report-map-cluster' : 'report-map-marker';
        if (cluster) {
          button.textContent = String(properties.point_count);
          button.setAttribute('aria-label', `Zoom in to ${properties.point_count} incidents`);
          button.title = `${properties.point_count} incidents · Zoom in`;
          const clusterRevision = revision;
          button.addEventListener('click', event => {
            event.stopPropagation();
            source.getClusterExpansionZoom(properties.cluster_id, (error, zoom) => {
              if (disposed || error || zoom == null || revision !== clusterRevision) return;
              map.easeTo({center: coordinates, zoom, duration: 400});
            });
          });
        } else {
          button.setAttribute('aria-controls', 'selected-trail-report');
          button.addEventListener('click', event => {event.stopPropagation(); onSelect(report!.id);});
          button.innerHTML = reportStatusMarker(report!.status);
          const label = `${reportStatusLabels[report!.status] || report!.status} · ${reportCategories[report!.category] || report!.category}: ${report!.description}`;
          button.setAttribute('aria-label', `Open report: ${label}`);
          button.title = label;
          button.dataset.selectedLabel = `${reportCategories[report!.category] || report!.category}: ${report!.description}`;
          reportStatuses.forEach(status => button.classList.toggle(`status-${status}`, report!.status === status));
        }
        marker = new gl.Marker({element: button, anchor: 'center'}).setLngLat(coordinates).addTo(map);
        button.setAttribute('role', 'button');
        markers.set(key, marker);
      }
      marker.setLngLat(coordinates);
      if (!cluster) {
        marker.getElement().classList.toggle('is-selected', report!.id === selectedId);
        marker.getElement().setAttribute('aria-pressed', String(report!.id === selectedId));
      }
    }
    markers.forEach((marker, key) => {if (!visible.has(key)) {marker.remove(); markers.delete(key);}});
  }
  map.on('render', render);
  return {
    update(next: TrailReport[]) {
      reports = new Map(next.map(report => [report.id, report]));
      revision++;
      clear(); // Do not leave old counts clickable while a filter change is processed.
      const data = {type: 'FeatureCollection' as const, features: next.map(report => ({
        type: 'Feature' as const, id: report.id, properties: {reportId: report.id, revision},
        geometry: {type: 'Point' as const, coordinates: [report.longitude, report.latitude]},
      }))};
      source.setData(data);
    },
    select(id: string) {
      selectedId = id;
      render();
      const report = reports.get(id);
      if (!report) return;
      const center: [number, number] = [report.longitude, report.latitude];
      // Reveal a list selection even when its individual marker is inside a cluster.
      if (!markers.has(`report:${id}`) && map.getZoom() <= clusterMaxZoom) {
        map.easeTo({center, zoom: clusterMaxZoom + 1, duration: 400});
        return;
      }
      const point = map.project(center), {width, height} = map.getContainer().getBoundingClientRect();
      const margin = Math.min(140, width / 2);
      if (point.x < margin || point.x > width - margin || point.y < 55 || point.y > height - 95) {
        map.easeTo({center, duration: 400});
      }
    },
    destroy() {
      if (disposed) return;
      disposed = true;
      map.off('render', render);
      clear();
      if (map.getLayer(sourceId)) map.removeLayer(sourceId);
      if (map.getSource(sourceId)) map.removeSource(sourceId);
    },
  };
}
