import type { Metadata } from 'next';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { TrailFigures } from '@/components/TrailFigures';
import { AppDownload } from '@/components/AppDownload';
import { CyprusTrailSlideshow } from '@/components/CyprusTrailSlideshow';
import {
  getPublicTrail,
  safePublicUrl,
  type PublicTrail,
} from '@/lib/public-trail-data';
import { buildItinerary } from '@/lib/web-itinerary';
import { publicNoticeHtml } from '@/lib/public-notices';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Explore the E4 Cyprus Trail',
  description:
    'Explore the E4 Cyprus trail: route map, elevation, daily itinerary planner, accommodation and current approved trail notices.',
  alternates: { canonical: '/trails/cyprus-e4' },
};
type Params = Record<string, string | string[] | undefined>;
const value = (params: Params, key: string) =>
  typeof params[key] === 'string' ? (params[key] as string) : '';
const date = (input: string) =>
  input && Number.isFinite(Date.parse(input))
    ? new Intl.DateTimeFormat('en-GB', {
        dateStyle: 'medium',
        timeZone: 'UTC',
      }).format(new Date(input))
    : 'Not recorded';

function pageUrl(params: Params, page: number) {
  const query = new URLSearchParams();
  for (const [key, item] of Object.entries(params))
    if (typeof item === 'string') query.set(key, item);
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
  const filtered = trail.lodgings.filter(
    (stay) =>
      (!type || stay.type === type) &&
      (!search ||
        [stay.name, stay.village, stay.stageName]
          .join(' ')
          .toLowerCase()
          .includes(search))
  );
  const page = Math.max(
    1,
    Math.min(
      Math.max(1, Math.ceil(filtered.length / 18)),
      Number.parseInt(value(params, 'page'), 10) || 1
    )
  );
  const shown = filtered.slice((page - 1) * 18, page * 18);
  const sum = (key: 'elevationUpM' | 'elevationDownM') =>
    trail.stages.slice(1).every((point) => point[key] !== null)
      ? trail.stages.slice(1).reduce((total, point) => total + point[key]!, 0)
      : null;
  const ascent = sum('elevationUpM'),
    descent = sum('elevationDownM');
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
          <header className="trail-guide-hero">
            <div className="section-shell">
              <div className="trail-guide-hero-grid">
                <div className="trail-guide-intro">
                  <p className="eyebrow">Explore Trails · {trail.country}</p>
                  <h1>E4 Cyprus</h1>
                  <p className="trail-guide-lead">
                    General Info, Map, Elevation Map. Find your way from{' '}
                    {first.name} to {last.name}, one walking day at a time.
                  </p>
                  <div className="editorial-actions">
                    <a className="button button-primary" href="#planner">
                      Plan your Journey
                    </a>
                    <a
                      className="button button-secondary"
                      href="#accommodations"
                    >
                      Accommodation Directory
                    </a>
                  </div>
                  <p className="guide-freshness">
                    Trail data updated {date(trail.updatedAt)}
                  </p>
                  <a
                    className="simple-link"
                    href="https://www.era-ewv-ferp.org/e-paths/e4/"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    E4 information from the European Hiking Federation (ERA) ↗
                  </a>
                </div>
                <CyprusTrailSlideshow />
              </div>
              <dl className="guide-stat-ribbon">
                <div>
                  <dt>Total distance</dt>
                  <dd>
                    {trail.distanceKm === null
                      ? 'Not recorded'
                      : `${trail.distanceKm.toFixed(1)} km`}
                  </dd>
                </div>
                <div>
                  <dt>Reference points</dt>
                  <dd>{trail.stages.length}</dd>
                </div>
                <div>
                  <dt>Total ascent / descent</dt>
                  <dd>
                    {ascent === null || descent === null
                      ? 'Not recorded'
                      : `${Math.round(ascent).toLocaleString('en-GB')} / ${Math.round(descent).toLocaleString('en-GB')} m`}
                  </dd>
                </div>
                <div>
                  <dt>Countries</dt>
                  <dd>
                    {trail.country ? '1 · ' + trail.country : 'Not recorded'}
                  </dd>
                </div>
              </dl>
            </div>
          </header>
          <nav
            className="section-shell editorial-subnav"
            aria-label="Trail guide sections"
          >
            <a href="#trail-map">Map &amp; Elevation</a>
            <a href="/trails/cyprus-e4/stages">Facilities &amp; Waypoints</a>
            <a href="#planner">Daily Stage Planner</a>
            <a href="#conditions">Trail Conditions</a>
            <a href="#accommodations">Accommodation</a>
            <a href="#app">Download App</a>
          </nav>
          <TrailFigures trail={trail} />
          <section className="section-shell planner-section" id="planner">
            <div className="editorial-split">
              <div>
                <p className="eyebrow">Smart Multi-Day Itinerary</p>
                <h2>
                  A walking rhythm
                  <br />
                  that fits you.
                </h2>
                <p>
                  Adjust your pacing to recalculate walking days and recorded
                  overnight stops. Each day includes the route points, water
                  sources and elevation along the way.
                </p>
              </div>
              <p className="data-caveat">
                Reference points are not prescribed walking days. Suggested
                stops use recorded accommodation and camping information;
                confirm access, permission and availability directly. Distances
                between reference points may differ slightly from the full route
                geometry.
              </p>
            </div>
            <form
              className="planner-form"
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
                >
                  Reset
                </a>
              </div>
            </form>
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
                          <span className="day-number">Day {day.number}</span>
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
                                    point.services.food ? 'Food recorded' : '',
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
                                href={pageUrl(
                                  { ...params, stay: day.end.name },
                                  1
                                )}
                              >
                                View stays →
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
          </section>
          <section className="section-shell conditions-section" id="conditions">
            <p className="eyebrow">Live Trail Conditions Noticeboard</p>
            <h2>Know what lies ahead.</h2>
            <p>
              Reviewed reports and approved trail notices. Updates can lag
              behind conditions on the ground.
            </p>
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
            <p className="data-caveat">
              Use the app to report a trail problem. Only reviewed public
              notices appear here; private reports and reporter contact details
              stay private.
            </p>
          </section>
          <section
            className="section-shell accommodation-directory"
            id="accommodations"
          >
            <p className="eyebrow">Accommodation Directory</p>
            <h2>A place to rest along the way.</h2>
            <p>
              Recorded stays from the trail directory. Contact hosts directly to
              confirm prices, access and availability; an imported entry is not
              a claim of verification.
            </p>
            <form
              className="directory-filters"
              {...{
                'hx-sync': 'this:replace',
                'hx-disabled-elt': 'find button[type="submit"]',
              }}
              method="get"
              action="/trails/cyprus-e4#accommodations"
            >
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
              <button type="submit" className="button button-primary">
                Find stays
              </button>
            </form>
            {!trail.lodgingsAvailable ? (
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
                          className="simple-link"
                          href={`/trails/cyprus-e4/stages/${stay.stageId}`}
                        >
                          {stay.stageName || 'Trail reference point'} →
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
                              href={`https://www.google.com/maps/search/?api=1&query=${stay.location.latitude},${stay.location.longitude}`}
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              GPS ↗
                            </a>
                          )}
                          {phone && <a href={phone}>Phone</a>}
                          {email && <a href={email}>Email</a>}
                          {website && (
                            <a
                              href={website}
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              Book ↗
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
                    >
                      ← Previous
                    </a>
                  )}
                  {page * 18 < filtered.length && (
                    <a
                      className="button button-secondary"
                      href={pageUrl(params, page + 1)}
                    >
                      Next stays →
                    </a>
                  )}
                </nav>
              </>
            )}
          </section>
          <AppDownload screenshots />
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
