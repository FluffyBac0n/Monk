import type { PublicTrail } from '@/lib/public-trail-data';
import { buildElevationProfile } from '@/lib/elevation-profile';

export function ElevationProfile({ trail }: { trail: PublicTrail }) {
  const profile = buildElevationProfile(trail.points, trail.distanceKm);
  if (!profile) return null;

  const y = (altitude: number) =>
    244 - ((altitude - profile.min) / (profile.max - profile.min)) * 226;
  const label = (value: number) =>
    value.toLocaleString('en-GB', { maximumFractionDigits: 1 });
  const plot = (width: number) => {
    const x = (distance: number) =>
      58 + (distance / profile.distance) * (width - 76);
    return (
      <svg
        className={width === 900 ? 'elevation-desktop' : 'elevation-mobile'}
        viewBox={`0 0 ${width} 286`}
        preserveAspectRatio="none"
        role="img"
        aria-label={`Recorded Cyprus E4 elevation over ${label(profile.distance)} kilometres. Altitudes shown on a smoothed profile, in metres.`}
      >
        <defs>
          <linearGradient
            id={`trail-altitude-fill-${width}`}
            x1="0"
            y1="244"
            x2="0"
            y2="18"
            gradientUnits="userSpaceOnUse"
          >
            {profile.gradient.map((stop) => (
              <stop
                key={stop.offset}
                offset={stop.offset}
                stopColor={stop.color}
                stopOpacity={148 / 255}
              />
            ))}
          </linearGradient>
        </defs>
        {profile.xTicks.map((tick) => (
          <g key={tick}>
            <line x1={x(tick)} x2={x(tick)} y1="18" y2="244" stroke="#f0f1ef" />
            <text
              x={x(tick)}
              y="271"
              textAnchor={
                tick === 0
                  ? 'start'
                  : tick === profile.distance
                    ? 'end'
                    : 'middle'
              }
            >
              {label(tick)} km
            </text>
          </g>
        ))}
        {profile.yTicks.map((tick) => (
          <g key={tick}>
            <line
              x1="58"
              x2={width - 18}
              y1={y(tick)}
              y2={y(tick)}
              stroke="#e2e5e1"
            />
            <text x="48" y={y(tick) + 4} textAnchor="end">
              {label(tick)} m
            </text>
          </g>
        ))}
        {profile.segments.map((segment, index) => {
          const line = segment
            .map(
              (point) =>
                `${x(point.distanceKm).toFixed(2)},${y(point.altitudeM).toFixed(2)}`
            )
            .join(' ');
          return (
            <g key={index}>
              <path
                d={`M${x(segment[0].distanceKm)} 244 L${line.replaceAll(' ', ' L')} L${x(segment.at(-1)!.distanceKm)} 244Z`}
                fill={`url(#trail-altitude-fill-${width})`}
              />
              <polyline
                points={line}
                stroke="#303e4e"
                strokeWidth="1.5"
                vectorEffect="non-scaling-stroke"
                strokeLinejoin="round"
                fill="none"
              />
            </g>
          );
        })}
      </svg>
    );
  };
  return (
    <figure className="route-elevation mobile-elevation">
      <h3>Elevation Profile</h3>
      <div className="elevation-plot">
        {plot(900)}
        {plot(360)}
      </div>
      <div className="elevation-legend" aria-label="Altitude colour scale">
        <div className="elevation-legend-bar" />
        <div className="elevation-legend-labels">
          <span>0 m</span>
          <span>300 m</span>
          <span>700 m</span>
          <span>1,200+ m</span>
        </div>
      </div>
      <figcaption>
        Distances and elevations from the recorded route, smoothed as in the
        EuroTrex app. Vertical scale is exaggerated.
      </figcaption>
    </figure>
  );
}
