import type { CyprusE4Stage } from '@/lib/cyprus-e4-data';
import type { PublicLodging, TrailPoint } from '@/lib/public-trail-data';

// Match the mobile app's service metaphors; keep labels visible beside each icon.
export function ServiceIcon({ service }: { service: string }) {
  const paths: Record<string, string> = {
    lodging: 'M3 18V7m18 11V10M3 14h18M7 10h3v4H7zM11 10h7a3 3 0 0 1 3 3v1',
    tent: 'M3 20 12 4l9 16H3Zm5 0 4-8 4 8',
    food: 'M5 3v7m4-7v7M3 3v5a4 4 0 0 0 8 0V3M7 12v9M19 3c-5 5-5 10 0 10V3Zm0 10v8',
    grocery: 'M3 4h3l3 12h10l2-8H7M10 21h.01M18 21h.01',
    drinkableWater: 'M12 3S5 11 5 15a7 7 0 0 0 14 0c0-4-7-12-7-12Z',
    nonDrinkableWater:
      'M12 3S5 11 5 15a7 7 0 0 0 14 0c0-4-7-12-7-12ZM3 3l18 18',
    toilets: 'M8 5h.01M16 5h.01M8 9v12m-3-6V9h6v6m2 0 3-6 3 6h-6Zm3 0v6',
    medical: 'M5 7h14v14H5zM9 7V3h6v4M12 11v6m-3-3h6',
    pharmacy: 'M9 3h6v6h6v6h-6v6H9v-6H3V9h6V3Z',
    atm: 'm3 8 9-5 9 5H3Zm2 4v6m7-6v6m7-6v6M3 21h18',
    busStop: 'M5 17V5q7-4 14 0v12H5Zm0-7h14M8 14h.01M16 14h.01M7 17v4m10-4v4',
  };
  return (
    <svg
      aria-hidden="true"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={paths[service] || 'm5 12 4 4L19 6'} />
    </svg>
  );
}

export function StageLocator({
  stage,
  points,
}: {
  stage: CyprusE4Stage;
  points: TrailPoint[];
}) {
  if (!stage.location) return null;
  const { latitude, longitude } = stage.location;
  if (!points.length)
    return (
      <p>
        <a
          className="simple-link"
          href={`https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=15/${latitude}/${longitude}`}
          target="_blank"
          rel="noopener noreferrer"
        >
          Open location map ↗
        </a>
      </p>
    );
  const minLat = Math.min(...points.map((point) => point.lat)),
    maxLat = Math.max(...points.map((point) => point.lat)),
    minLng = Math.min(...points.map((point) => point.lng)),
    maxLng = Math.max(...points.map((point) => point.lng));
  const sample = points.filter(
    (_, index) =>
      index % Math.max(1, Math.ceil(points.length / 450)) === 0 ||
      index === points.length - 1
  );
  const routePath = sample
    .map(
      (point, index) =>
        `${index === 0 ? 'M' : 'L'}${30 + ((point.lng - minLng) / (maxLng - minLng || 1)) * 540},${190 - ((point.lat - minLat) / (maxLat - minLat || 1)) * 160}`
    )
    .join(' ');
  const x = 30 + ((longitude - minLng) / (maxLng - minLng || 1)) * 540;
  const y = 190 - ((latitude - minLat) / (maxLat - minLat || 1)) * 160;
  return (
    <figure className="stage-locator">
      <svg
        viewBox="0 0 600 230"
        role="img"
        aria-label={`${stage.name} on the Cyprus-E4 route. Schematic locator, not a navigation map.`}
      >
        <path d={routePath} fill="none" stroke="var(--blue)" strokeWidth="2" />
        <circle
          cx={x}
          cy={y}
          r="8"
          fill="var(--gold)"
          stroke="var(--navy)"
          strokeWidth="2"
        />
        <text x="30" y="218" fill="var(--navy)" fontSize="12">
          Pafos → Larnaka
        </text>
      </svg>
      <figcaption>
        <strong>{stage.name}</strong>
        <span>Route locator · not to scale</span>
        <a
          href={`https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=15/${latitude}/${longitude}`}
          target="_blank"
          rel="noopener noreferrer"
        >
          Open location map ↗
        </a>
      </figcaption>
    </figure>
  );
}

function safeLink(value: string | null) {
  if (!value) return null;
  try {
    const url = new URL(value);
    return ['http:', 'https:'].includes(url.protocol) &&
      !url.username &&
      !url.password
      ? url.href
      : null;
  } catch {
    return null;
  }
}

export function StageStays({
  stage,
  lodgings,
  available,
}: {
  stage: CyprusE4Stage;
  lodgings: PublicLodging[];
  available: boolean;
}) {
  const stays = lodgings.filter((stay) => stay.stageId === stage.id);
  return (
    <section className="stage-section">
      <p className="eyebrow">Accommodation</p>
      <h2>
        {!available
          ? 'Accommodation directory unavailable.'
          : stays.length
          ? 'Places recorded near this point.'
          : 'No accommodation recorded yet.'}
      </h2>
      <p>
        {available
          ? 'These entries come from the trail directory, not a live room-availability feed or a claim of host verification. Confirm access, prices and suitability directly.'
          : 'The accommodation directory could not be refreshed. Please try again.'}
      </p>
      <ul className="recorded-stays">
        {stays.map((stay) => {
          const website = safeLink(stay.website),
            map = stay.location
              ? `https://www.openstreetmap.org/?mlat=${stay.location.latitude}&mlon=${stay.location.longitude}#map=15/${stay.location.latitude}/${stay.location.longitude}`
              : null;
          return (
            <li key={stay.id}>
              <strong>{stay.name}</strong>
              <span>
                {[stay.type, stay.village].filter(Boolean).join(' · ')}
              </span>
              <div>
                {website && (
                  <a href={website} target="_blank" rel="noopener noreferrer">
                    Contact / website ↗
                  </a>
                )}
                {map && (
                  <a href={map} target="_blank" rel="noopener noreferrer">
                    Location ↗
                  </a>
                )}
              </div>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
