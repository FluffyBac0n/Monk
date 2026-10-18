import { TrailDivider } from '@/components/TrailDivider';
import type { Metadata } from 'next';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { TrailFigures } from '@/components/TrailFigures';
import { AppDownload } from '@/components/AppDownload';
import {
  getPublicTrail,
  safePublicUrl,
  type PublicTrail,
} from '@/lib/public-trail-data';
import { buildItinerary } from '@/lib/web-itinerary';
import { publicNoticeHtml } from '@/lib/public-notices';
import { publicHtmxNavigation, inPlaceTrailSection } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Explore the E4 Cyprus Trail',
  description:
    'Explore the E4 Cyprus trail: route map, elevation, daily itinerary planner, accommodation and current approved trail notices.',
  alternates: { canonical: '/trails/cyprus-e4' },
};
type Params = Record<string, string | string[] | undefined>;
const value = (params: Params, key: string) =>
  typeof params[key] === 'string' ? (params[key] as string) : '';

function pageUrl(params: Params, page: number) {
  const query = new URLSearchParams();
  for (const [key, item] of Object.entries(params))
    if (typeof item === 'string') query.set(key, item);
  query.set('findStays', 'yes');
  query.set('page', String(page));
  return `/trails/cyprus-e4?${query}#accommodations`;
}

export default async function CyprusE4({
  searchParams,
}: {
  searchParams: Promise<Params>;
}) {
  const params = await searchParams;
  let trail: PublicTrail | null = null;
  try {
    trail = await getPublicTrail();
  } catch {
    /* Render a bounded, useful unavailable state. */
  }
  if (!trail)
    return (
      <>
        <PublicHeader activeTrail="cyprus-e4" />
        <PublicContent>
          <main
            id="main-content"
            className="content-page"
            {...publicHtmxNavigation}
          >
            <section className="section-shell foundation-section">
              <p className="eyebrow">E4 Cyprus</p>
              <h1>The trail guide is temporarily unavailable.</h1>
              <p>
                We could not refresh the trail information. Please try again
                shortly.
              </p>
              <a className="button button-primary" href="/trails/cyprus-e4">
                Retry trail information
              </a>
            </section>
            <AppDownload />
          </main>
        </PublicContent>
        <PublicFooter />
      </>
    );
  const first = trail.stages[0],
    last = trail.stages.at(-1)!;
  const start = value(params, 'start') || first.id,
    end = value(params, 'end') || last.id;
  const maxKm = value(params, 'maxKm') ? Number(value(params, 'maxKm')) : 30;
  const requestedDays = value(params, 'days')
    ? Number(value(params, 'days'))
    : undefined;
  const camping = params.plan === 'yes' ? params.camping === 'yes' : true;
  const itinerary = buildItinerary(trail.stages, trail.lodgings, {
    start,
    end,
    maxKm,
    days: requestedDays,
    camping,
  });
  const search = value(params, 'stay').toLowerCase().trim(),
    type = value(params, 'type');
  const hasStaySearch = params.findStays === 'yes' || Boolean(search || type);
  const filtered = hasStaySearch
    ? trail.lodgings.filter(
        (stay) =>
          (!type || stay.type === type) &&
          (!search ||
            [stay.name, stay.village, stay.stageName]
              .join(' ')
              .toLowerCase()
              .includes(search))
      )
    : [];
  const page = Math.max(
    1,
    Math.min(
      Math.max(1, Math.ceil(filtered.length / 18)),
      Number.parseInt(value(params, 'page'), 10) || 1
    )
  );
  const shown = filtered.slice((page - 1) * 18, page * 18);
  return (
    <>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <PublicHeader activeTrail="cyprus-e4" />
      <PublicContent>
        <main
          id="main-content"
          className="content-page"
          data-trail-guide="cyprus-e4"
          tabIndex={-1}
          {...publicHtmxNavigation}
        >
          <TrailFigures trail={trail} />
          <TrailDivider />
          <section
            className="section-shell guide-journey explore-section"
            aria-labelledby="stages-title"
          >
            <div className="guide-section-heading">
              <h2 className="section-title" id="stages-title">
                Daily Stage Planner
              </h2>
              <a
                className="button button-secondary fill-link cta-button"
                href="/trails/cyprus-e4/stages"
              >
                View all {trail.stages.length} points
              </a>
            </div>
            <ol className="guide-waypoint-list">
              {[0, 0.25, 0.5, 0.75, 1].map((part, index) => {
                const point =
                  trail.stages[Math.round(part * (trail.stages.length - 1))];
                return (
                  <li key={point.id}>
                    <a href={`/trails/cyprus-e4/stages/${point.id}`}>
                      <span className="guide-waypoint-dot" aria-hidden="true" />
                      <small>
                        {index === 0
                          ? 'Start'
                          : index === 4
                            ? 'Finish'
                            : `${point.accumulatedDistanceKm?.toFixed(0)} km`}
                      </small>
                      <strong>{point.name}</strong>
                      <span>
                        {point.altitudeM === null
                          ? 'Altitude not recorded'
                          : `${Math.round(point.altitudeM)} m altitude`}
                      </span>
                    </a>
                  </li>
                );
              })}
            </ol>
          </section>
          <TrailDivider />
          <section
            className="section-shell planner-section explore-section"
            id="planner"
            aria-labelledby="planner-title"
          >
            <h2 className="section-title" id="planner-title">
              Smart Multi-Day Itinerary
            </h2>
            <div className="planner-workspace">
              <form
                className="planner-form"
                {...inPlaceTrailSection('planner')}
                action="/trails/cyprus-e4#planner"
                method="get"
                {...{
                  'hx-sync': 'this:replace',
                  'hx-disabled-elt': 'find button[type="submit"]',
                }}
              >
                <input type="hidden" name="plan" value="yes" />
                <label>
                  Start Point
                  <select name="start" defaultValue={start}>
                    {trail.stages.map((point) => (
                      <option key={point.id} value={point.id}>
                        {point.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  End Point
                  <select name="end" defaultValue={end}>
                    {trail.stages.map((point) => (
                      <option key={point.id} value={point.id}>
                        {point.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  No. of Days{' '}
                  <span className="optional-marker">(Auto if blank)</span>
                  <input
                    name="days"
                    type="number"
                    min="1"
                    max="90"
                    defaultValue={value(params, 'days')}
                    placeholder="Auto"
                  />
                </label>
                <label>
                  Max km per day
                  <input
                    name="maxKm"
                    type="number"
                    min="5"
                    max="80"
                    step=".5"
                    defaultValue={maxKm}
                  />
                </label>
                <label className="check-label">
                  <input
                    name="camping"
                    type="checkbox"
                    value="yes"
                    defaultChecked={camping}
                  />
                  <span>Include recorded camping stops</span>
                </label>
                <div className="editorial-actions">
                  <button className="button button-primary" type="submit">
                    Build my itinerary
                  </button>
                  <a
                    className="button button-secondary"
                    href="/trails/cyprus-e4#planner"
                    {...inPlaceTrailSection('planner')}
                  >
                    Reset
                  </a>
                </div>
              </form>
              <div className="planner-stage-column">
                {itinerary.error ? (
                  <div className="trail-data-message" role="status">
                    <h3>Try a different walking plan.</h3>
                    <p>{itinerary.error}</p>
                  </div>
                ) : (
                  <div className="itinerary-results" aria-live="polite">
                    <p className="itinerary-summary">
                      <strong>
                        {itinerary.days.length} walking{' '}
                        {itinerary.days.length === 1 ? 'day' : 'days'} ·{' '}
                        {itinerary.distanceKm.toFixed(1)} km
                      </strong>
                      <span>
                        {itinerary.days[0].start.name} →{' '}
                        {itinerary.days.at(-1)!.end.name}
                      </span>
                    </p>
                    <ol className="itinerary-days">
                      {itinerary.days.map((day) => (
                        <li key={day.number}>
                          <details>
                            <summary>
                              <span className="day-number">
                                Day {day.number}
                              </span>
                              <span>
                                <strong>
                                  {day.start.name} → {day.end.name}
                                </strong>
                                <small>
                                  {day.distanceKm.toFixed(1)} km · ↑{' '}
                                  {day.ascentM === null
                                    ? 'not recorded'
                                    : Math.round(day.ascentM) + ' m'}{' '}
                                  · ↓{' '}
                                  {day.descentM === null
                                    ? 'not recorded'
                                    : Math.round(day.descentM) + ' m'}
                                </small>
                              </span>
                              <span className="day-expand" aria-hidden="true">
                                +
                              </span>
                            </summary>
                            <div className="day-details">
                              <ol>
                                {day.points.map((point) => (
                                  <li key={point.id}>
                                    <a
                                      href={`/trails/cyprus-e4/stages/${point.id}`}
                                    >
                                      {point.name}
                                    </a>
                                    <span>
                                      {[
                                        point.services.drinkableWater
                                          ? 'Drinking water recorded'
                                          : '',
                                        point.services.food
                                          ? 'Food recorded'
                                          : '',
                                        point.services.lodging
                                          ? 'Lodging recorded'
                                          : '',
                                      ]
                                        .filter(Boolean)
                                        .join(' · ')}
                                    </span>
                                  </li>
                                ))}
                              </ol>
                              <p>
                                <strong>Overnight at {day.end.name}:</strong>{' '}
                                {day.lodgings.length
                                  ? `${day.lodgings.length} recorded places to stay.`
                                  : day.end.services.lodging
                                    ? 'Lodging is recorded at this point.'
                                    : day.camping
                                      ? 'Camping is recorded; confirm current access and permission.'
                                      : 'Journey finish; arrange your onward plans.'}{' '}
                                {day.lodgings.length > 0 && (
                                  <a
                                    className="button button-secondary fill-link cta-button"
                                    href={pageUrl(
                                      { ...params, stay: day.end.name },
                                      1
                                    )}
                                  >
                                    View stays
                                  </a>
                                )}
                              </p>
                            </div>
                          </details>
                        </li>
                      ))}
                    </ol>
                  </div>
                )}
              </div>
            </div>
          </section>
          <TrailDivider />
          <section
            className="section-shell conditions-section explore-section"
            id="conditions"
            aria-labelledby="conditions-title"
          >
            <h2 className="section-title" id="conditions-title">
              Live Trail Conditions Noticeboard
            </h2>
            <div
              data-trail-notices
              {...{
                'hx-get': '/api/trail-notices',
                'hx-trigger': 'every 60s',
                'hx-target': 'this',
                'hx-swap': 'innerHTML',
                'hx-select': 'unset',
                'hx-push-url': 'false',
                'hx-boost': 'false',
              }}
              dangerouslySetInnerHTML={{
                __html: publicNoticeHtml(trail.issues, trail.issuesAvailable),
              }}
            />
          </section>
          <TrailDivider />
          <section
            className="section-shell accommodation-directory explore-section"
            aria-labelledby="accommodations-title"
            id="accommodations"
          >
            <h2 className="section-title" id="accommodations-title">
              Accommodation Directory
            </h2>
            <form
              className="directory-filters"
              {...inPlaceTrailSection('accommodations')}
              {...{
                'hx-sync': 'this:replace',
                'hx-disabled-elt': 'find button[type="submit"]',
              }}
              method="get"
              action="/trails/cyprus-e4#accommodations"
            >
              <input type="hidden" name="findStays" value="yes" />
              {['plan', 'start', 'end', 'days', 'maxKm', 'camping'].map(
                (key) =>
                  value(params, key) ? (
                    <input
                      type="hidden"
                      key={key}
                      name={key}
                      value={value(params, key)}
                    />
                  ) : null
              )}
              <label>
                Find a place
                <input
                  type="search"
                  name="stay"
                  defaultValue={value(params, 'stay')}
                  placeholder="Name, village or trail point"
                  maxLength={160}
                />
              </label>
              <label>
                Accommodation type
                <select name="type" defaultValue={type}>
                  <option value="">All types</option>
                  {[
                    ...new Set(
                      trail.lodgings.map((stay) => stay.type).filter(Boolean)
                    ),
                  ]
                    .sort()
                    .map((item) => (
                      <option key={item}>{item}</option>
                    ))}
                </select>
              </label>
              <div className="directory-actions">
                <button
                  type="submit"
                  className="button button-primary fill-link"
                >
                  Find stays
                </button>
                <a
                  className="button button-secondary fill-link"
                  href="/trails/cyprus-e4#accommodations"
                  {...inPlaceTrailSection('accommodations')}
                >
                  Reset
                </a>
              </div>
            </form>
            {hasStaySearch &&
              (!trail.lodgingsAvailable ? (
                <p className="trail-data-message">
                  The accommodation directory could not be refreshed.{' '}
                  <a href="/trails/cyprus-e4#accommodations">Try again</a>.
                </p>
              ) : (
                <>
                  <p role="status">
                    {filtered.length
                      ? `Showing ${(page - 1) * 18 + 1}–${Math.min(page * 18, filtered.length)} of ${filtered.length} recorded stays`
                      : 'No stays match your search.'}
                  </p>
                  <div className="public-stays-grid">
                    {shown.map((stay) => {
                      const phone = safePublicUrl(stay.phone, 'phone'),
                        email = safePublicUrl(stay.email, 'email'),
                        website = safePublicUrl(stay.website);
                      return (
                        <article className="public-stay" key={stay.id}>
                          <p className="eyebrow">
                            {stay.type || 'Accommodation'}
                          </p>
                          <h3>
                            {stay.name ||
                              [
                                stay.type || 'Accommodation',
                                stay.stageName || stay.village,
                              ]
                                .filter(Boolean)
                                .join(' · ')}
                          </h3>
                          {stay.verified && (
                            <span
                              className="verified-stay"
                              title="Reviewed representative authority, contact details and trail relevance"
                            >
                              ✓ Eurotrex Verified Stay
                            </span>
                          )}
                          <p>{stay.village || stay.address}</p>
                          <a
                            className="button button-secondary fill-link cta-button"
                            href={`/trails/cyprus-e4/stages/${stay.stageId}`}
                          >
                            {stay.stageName || 'Trail reference point'}
                          </a>
                          <p className="stay-price">
                            {stay.priceMinEur !== null ||
                            stay.priceMaxEur !== null
                              ? `€${stay.priceMinEur ?? stay.priceMaxEur}${stay.priceMaxEur !== null && stay.priceMinEur !== null && stay.priceMaxEur !== stay.priceMinEur ? '–' + stay.priceMaxEur : ''} / night`
                              : 'Ask the host for prices'}
                          </p>
                          <div className="stay-actions">
                            {stay.location && (
                              <a
                                className="button button-secondary fill-link cta-button"
                                href={`https://www.google.com/maps/search/?api=1&query=${stay.location.latitude},${stay.location.longitude}`}
                                target="_blank"
                                rel="noopener noreferrer"
                              >
                                GPS
                              </a>
                            )}
                            {phone && (
                              <a
                                className="button button-secondary fill-link cta-button"
                                href={phone}
                              >
                                Phone
                              </a>
                            )}
                            {email && (
                              <a
                                className="button button-secondary fill-link cta-button"
                                href={email}
                              >
                                Email
                              </a>
                            )}
                            {website && (
                              <a
                                className="button button-secondary fill-link cta-button"
                                href={website}
                                target="_blank"
                                rel="noopener noreferrer"
                              >
                                Book
                              </a>
                            )}
                          </div>
                        </article>
                      );
                    })}
                  </div>
                  <nav
                    className="directory-pagination"
                    aria-label="Accommodation pages"
                  >
                    {page > 1 && (
                      <a
                        className="button button-secondary"
                        href={pageUrl(params, page - 1)}
                        {...inPlaceTrailSection(
                          'accommodations',
                          pageUrl(params, page - 1)
                        )}
                      >
                        Previous
                      </a>
                    )}
                    {page * 18 < filtered.length && (
                      <a
                        className="button button-secondary"
                        href={pageUrl(params, page + 1)}
                        {...inPlaceTrailSection(
                          'accommodations',
                          pageUrl(params, page + 1)
                        )}
                      >
                        Next stays
                      </a>
                    )}
                  </nav>
                </>
              ))}
          </section>
          <TrailDivider />
          <AppDownload screenshots />
          <TrailDivider />
          <section
            className="section-shell guide-essentials"
            id="walking-essentials"
            aria-labelledby="walking-essentials-title"
          >
            <article className="guide-plan-copy">
              <p className="eyebrow">Shape your own walk</p>
              <h2 id="walking-essentials-title">
                A route, not one fixed itinerary.
              </h2>
              <p>
                Named points give you the building blocks. Compare distance and
                elevation, then create walking days around your experience,
                daylight, accommodation and water plan.
              </p>
              <dl className="guide-planning-list">
                <div>
                  <dt>Choose your rhythm</dt>
                  <dd>
                    Link short or long sections instead of following a
                    prescribed schedule.
                  </dd>
                </div>
                <div>
                  <dt>Walk either way</dt>
                  <dd>
                    EuroTrex supports both directions; the public guide follows
                    Pafos to Larnaka for consistency.
                  </dd>
                </div>
                <div>
                  <dt>Check live conditions</dt>
                  <dd>
                    Use current local advice for weather, closures, water and
                    transport before setting out.
                  </dd>
                </div>
              </dl>
            </article>
            <aside className="guide-safety-panel">
              <p className="eyebrow light">Before you walk</p>
              <h2>
                Check the present,
                <br />
                not only the plan.
              </h2>
              <ul>
                <li>
                  <span>01</span>Confirm official access advice and weather.
                </li>
                <li>
                  <span>02</span>Carry enough water for changing conditions.
                </li>
                <li>
                  <span>03</span>Download trail data before limited coverage.
                </li>
                <li>
                  <span>04</span>Share your route and expected finish.
                </li>
              </ul>
              <div className="guide-emergency">
                <small>Emergency in Cyprus</small>
                <strong>112</strong>
              </div>
            </aside>
          </section>
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
