import { env } from 'cloudflare:workers';
import { ElevationProfile } from '@/components/ElevationProfile';
import { MapFlag } from '@/components/MapFlag';
import { trailMapCamera } from '@/lib/trail-map-image';
import type { PublicTrail } from '@/lib/public-trail-data';

export function TrailFigures({ trail }: { trail: PublicTrail }) {
  if (!trail.geometryAvailable)
    return (
      <section className="section-shell trail-data-message">
        <h2>Map and elevation</h2>
        <p>
          The route could not be refreshed. The reference points below are still
          available.
        </p>
        <a href="/trails/cyprus-e4#trail-map">Retry the route</a>
      </section>
    );
  const stride = Math.max(1, Math.ceil(trail.points.length / 1100));
  const points = trail.points.filter(
    (_, index) => index % stride === 0 || index === trail.points.length - 1
  );
  const lats = points.map((point) => point.lat),
    lngs = points.map((point) => point.lng);
  const bounds = {
    minLat: Math.min(...lats),
    maxLat: Math.max(...lats),
    minLng: Math.min(...lngs),
    maxLng: Math.max(...lngs),
  };
  const x = (lng: number) =>
    32 + ((lng - bounds.minLng) / (bounds.maxLng - bounds.minLng || 1)) * 836;
  const y = (lat: number) =>
    290 - ((lat - bounds.minLat) / (bounds.maxLat - bounds.minLat || 1)) * 235;
  const route = points
    .map((point) => `${x(point.lng).toFixed(1)},${y(point.lat).toFixed(1)}`)
    .join(' ');
  const token = (env as unknown as Record<string, unknown>)
    .MAPBOX_PUBLIC_ACCESS_TOKEN;
  const mapConfigured = typeof token === 'string' && token.startsWith('pk.');
  const metric = (key: 'elevationUpM' | 'elevationDownM') =>
    trail.stages.slice(1).every((point) => point[key] !== null)
      ? Math.round(
          trail.stages.slice(1).reduce((sum, point) => sum + point[key]!, 0)
        ).toLocaleString('en-GB')
      : 'Not recorded';
  const first = trail.stages[0],
    last = trail.stages.at(-1)!;
  const camera = trailMapCamera(trail.points);
  return (
    <section
      className="section-shell route-figures explore-section"
      id="trail-map"
      aria-labelledby="overview-title"
    >
      <div className="trail-overview-heading">
        <h1 className="section-title" id="overview-title">
          Trail Overview Dashboard
        </h1>
        <a
          className="era-link"
          href="https://www.era-ewv-ferp.org/e-paths/e4/"
          target="_blank"
          rel="noopener noreferrer"
        >
          E4 information from the European Hiking Federation (ERA)
        </a>
      </div>
      <div className="trail-map-dashboard">
        <dl className="trail-map-statistics">
          <div>
            <dt>Total distance</dt>
            <dd>
              {trail.distanceKm === null
                ? 'Not recorded'
                : `${trail.distanceKm.toFixed(1)} km`}
            </dd>
          </div>
          <div>
            <dt>Total elevation up / down</dt>
            <dd>
              {metric('elevationUpM')} / {metric('elevationDownM')} m
            </dd>
          </div>
          <div>
            <dt>Reference points</dt>
            <dd>{trail.stages.length}</dd>
          </div>
          <div>
            <dt>Start – end towns</dt>
            <dd>Paphos – Larnaca</dd>
          </div>
        </dl>
        <figure className="live-route-map guide-map-frame">
          {mapConfigured && (
            <div className="geographic-map-image">
              <img
                className="recorded-geographic-map"
                data-route-map-image
                src="/api/trail-map"
                alt={`Map of Cyprus showing the recorded E4 from ${first.name} to ${last.name}`}
                width="1200"
                height="700"
              />
              <div className="geographic-flags">
                <span
                  className="route-endpoint-flag"
                  role="img"
                  aria-label={`Start: ${first.name}`}
                  style={{
                    left: `${camera.start.x / 12}%`,
                    top: `${camera.start.y / 7}%`,
                  }}
                >
                  <MapFlag />
                </span>
                <span
                  className="route-endpoint-flag"
                  role="img"
                  aria-label={`Finish: ${last.name}`}
                  style={{
                    left: `${camera.finish.x / 12}%`,
                    top: `${camera.finish.y / 7}%`,
                  }}
                >
                  <MapFlag finish />
                </span>
              </div>
            </div>
          )}
          <div data-route-map-fallback hidden={mapConfigured}>
            <svg
              viewBox="0 0 900 350"
              role="img"
              aria-label={`Recorded Cyprus E4 route from ${first.name} to ${last.name}`}
            >
              <defs>
                <pattern
                  id="map-grid"
                  width="36"
                  height="36"
                  patternUnits="userSpaceOnUse"
                >
                  <path
                    d="M36 0H0V36"
                    fill="none"
                    stroke="#cfddd5"
                    strokeWidth=".7"
                  />
                </pattern>
              </defs>
              <rect width="900" height="350" rx="18" fill="#e6ede7" />
              <rect width="900" height="350" fill="url(#map-grid)" />
              <text x="48" y="38" className="map-region">
                CYPRUS · E4
              </text>
              <polyline
                points={route}
                fill="none"
                stroke="white"
                strokeWidth="7"
                strokeLinejoin="round"
              />
              <polyline
                points={route}
                fill="none"
                stroke="#2d5dd3"
                strokeWidth="3"
                strokeLinejoin="round"
              />
              {trail.stages
                .filter(
                  (point, index) =>
                    point.location &&
                    (index === 0 ||
                      index === trail.stages.length - 1 ||
                      index % 10 === 0)
                )
                .map((point) => (
                  <a
                    key={point.id}
                    href={`/trails/cyprus-e4/stages/${point.id}`}
                  >
                    <circle
                      cx={x(point.location!.longitude)}
                      cy={y(point.location!.latitude)}
                      r="5"
                      fill="#f2c94c"
                      stroke="#303e4e"
                      strokeWidth="1.5"
                    >
                      <title>{point.name}</title>
                    </circle>
                  </a>
                ))}
              {[points[0], points.at(-1)!].map((point, index) => (
                <svg
                  key={index}
                  className="fallback-map-flag"
                  x={x(point.lng) - 21}
                  y={y(point.lat) - 21}
                  width="42"
                  height="42"
                >
                  <MapFlag finish={index === 1} />
                </svg>
              ))}
              <text x="32" y="330">
                {first.name} → {last.name}
              </text>
            </svg>
          </div>
          <figcaption className="guide-map-caption">
            <span className="guide-map-legend">
              <i aria-hidden="true" />
              Cyprus-E4 · Paphos – Larnaca
            </span>
            <span>
              {trail.distanceKm?.toFixed(1)} km · {trail.stages.length}{' '}
              reference points
            </span>
            <small>Mapbox · © OpenStreetMap</small>
          </figcaption>
        </figure>
      </div>
      <ElevationProfile trail={trail} />
    </section>
  );
}
