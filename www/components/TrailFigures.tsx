import { env } from 'cloudflare:workers';
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
  const elevation = points.filter(
    (point) => point.altitudeM !== null && point.distanceKm !== null
  );
  const peak =
    trail.highPointM ??
    Math.max(...elevation.map((point) => point.altitudeM!), 1);
  const total = trail.distanceKm || elevation.at(-1)?.distanceKm || 1;
  const chart = elevation
    .map(
      (point) =>
        `${(40 + (point.distanceKm! / total) * 820).toFixed(1)},${(220 - (Math.max(0, point.altitudeM!) / Math.max(peak, 1)) * 180).toFixed(1)}`
    )
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
  return (
    <section className="section-shell route-figures" id="trail-map">
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
            <dd>
              {first.name}
              <br />→ {last.name}
            </dd>
          </div>
        </dl>
        <figure className="live-route-map guide-map-frame">
          {mapConfigured && (
            <img
              className="recorded-geographic-map"
              data-route-map-image
              src="/api/trail-map"
              alt={`Map of Cyprus showing the recorded E4 from ${first.name} to ${last.name}`}
              width="1200"
              height="700"
            />
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
              <text x="32" y="330">
                {first.name} → {last.name}
              </text>
            </svg>
          </div>
          <figcaption className="guide-map-caption">
            <span className="guide-map-legend">
              <i aria-hidden="true" />
              Cyprus-E4 · Pafos to Larnaka
            </span>
            <span>
              {trail.distanceKm?.toFixed(1)} km · {trail.stages.length}{' '}
              reference points
            </span>
            <small>Mapbox · © OpenStreetMap</small>
          </figcaption>
        </figure>
      </div>
      {elevation.length > 1 && (
        <figure className="route-elevation screenshot-elevation">
          <h3>Elevation Profile</h3>
          <svg
            viewBox="0 0 900 270"
            preserveAspectRatio="none"
            role="img"
            aria-label={`Elevation along the Cyprus E4, with a recorded high point of ${Math.round(peak)} metres`}
          >
            <path
              d={`M40 220 L${chart.replaceAll(' ', ' L')} L${40 + (elevation.at(-1)!.distanceKm! / total) * 820} 220Z`}
              fill="#266487"
            />
            <polyline
              points={chart}
              fill="none"
              stroke="#62b1dc"
              strokeWidth="2.5"
            />
            {[0, 0.5, 1].map((part) => (
              <g key={part}>
                <line
                  x1="40"
                  y1={220 - part * 180}
                  x2="860"
                  y2={220 - part * 180}
                  stroke="#ffffff"
                  strokeOpacity=".15"
                />
                <text x="0" y={225 - part * 180}>
                  {Math.round(peak * part)} m
                </text>
                <text
                  x={40 + 820 * part}
                  y="252"
                  textAnchor={part === 1 ? 'end' : 'start'}
                >
                  {(total * part).toFixed(0)} km
                </text>
              </g>
            ))}
          </svg>
          <figcaption>
            Distances and elevations from the recorded route; vertical scale is
            exaggerated.
          </figcaption>
        </figure>
      )}
    </section>
  );
}
