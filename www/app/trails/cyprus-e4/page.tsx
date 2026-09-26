import Image from 'next/image';
import type { Metadata } from 'next';
import { CyprusTrailSlideshow } from '@/components/CyprusTrailSlideshow';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { cyprusE4, cyprusE4Stages } from '@/lib/cyprus-e4-data';
import { publicHtmxNavigation } from '@/lib/htmx';
import { SITE_URL } from '@/lib/site';

export const metadata: Metadata = {
  title: 'Cyprus E4 trail guide',
  description: 'Explore the 558 km Cyprus E4 from Pafos to Larnaka, with 123 named stage points, elevation and recorded services.',
  alternates: { canonical: '/trails/cyprus-e4' },
};

const serviceCounts = Object.entries(cyprusE4Stages.reduce<Record<string, number>>((counts, stage) => {
  Object.entries(stage.services).forEach(([service, available]) => { if (available) counts[service] = (counts[service] || 0) + 1; });
  return counts;
}, {}));

const serviceLabels: Record<string, string> = {
  lodging: 'stays', tent: 'camping', food: 'food', grocery: 'groceries', drinkableWater: 'drinking water', toilets: 'toilets', medical: 'medical help', pharmacy: 'pharmacies', atm: 'ATMs', busStop: 'bus stops',
};

export default function CyprusE4Overview() {
  const updated = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(cyprusE4.dataUpdatedAt));
  const featuredStages = [cyprusE4Stages[0], cyprusE4Stages[30], cyprusE4Stages[61], cyprusE4Stages[92], cyprusE4Stages[122]];
  const schema = {
    '@context': 'https://schema.org', '@type': 'Route', name: 'Cyprus E4', url: `${SITE_URL}/trails/cyprus-e4`,
    description: 'A long-distance hiking route across Cyprus from Pafos Airport to Larnaka Airport.', image: `${SITE_URL}/cyprus-e4-forest.jpg`,
  };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <PublicHeader activeTrail="cyprus-e4" />
      <PublicContent>
      <main id="main-content" className="content-page" data-trail-guide="cyprus-e4" tabIndex={-1} {...publicHtmxNavigation}>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
        <header className="trail-guide-hero">
          <div className="section-shell">
            <div className="trail-guide-hero-grid">
              <div className="trail-guide-intro">
                <p className="eyebrow">Cyprus E4 trail guide</p>
                <h1>The Cyprus E4, from coast to mountains.</h1>
                <p className="trail-guide-lead">Follow 558 kilometres from Pafos to Larnaka through open coast, village country, pine forest and the Troodos highlands.</p>
                <div className="trail-guide-actions">
                  <a className="button button-primary fill-link" href="/trails/cyprus-e4/stages"><span>Explore {cyprusE4.stageCount} stage points</span></a>
                  <a className="guide-inline-link" href="/#hikers">Plan with EuroTrex <span aria-hidden="true">→</span></a>
                </div>
                <p className="guide-freshness"><span aria-hidden="true" />Trail snapshot updated {updated}</p>
              </div>
              <CyprusTrailSlideshow />
            </div>
            <dl className="guide-stat-ribbon">
              <div><dt>Route</dt><dd>{cyprusE4.distanceKm.toFixed(0)} km</dd></div>
              <div><dt>Stage points</dt><dd>{cyprusE4.stageCount}</dd></div>
              <div><dt>High point</dt><dd>{Math.round(cyprusE4.highPointM).toLocaleString('en-GB')} m</dd></div>
              <div><dt>Direction</dt><dd>Pafos → Larnaka</dd></div>
            </dl>
          </div>
        </header>

        <div className="trail-divider" aria-hidden="true" />

        <section className="section-shell guide-landscape reveal">
          <figure className="guide-coast-image">
            <Image src="/zapalo-coast-hero.webp" alt="Zapalo Bay’s limestone cliffs and coastal trail above the Mediterranean in Cyprus" fill sizes="(max-width: 900px) 100vw, 55vw" />
            <figcaption>Cyprus coast · Mediterranean light</figcaption>
          </figure>
          <article className="guide-landscape-copy">
            <p className="eyebrow">One line across an island</p>
            <h2>Every section changes the view.</h2>
            <p>The E4 begins at Pafos Airport and reaches Larnaka Airport after a long crossing of Cyprus. Use the guide to understand distance, elevation and useful services, then shape the trail around your own pace.</p>
            <ul className="guide-landscape-list" role="list">
              <li><span aria-hidden="true">01</span><div><strong>Coastal ground</strong><small>Sea air, open horizons and exposed sections.</small></div></li>
              <li><span aria-hidden="true">02</span><div><strong>Forest paths</strong><small>Shade, climbing terrain and quieter stretches.</small></div></li>
              <li><span aria-hidden="true">03</span><div><strong>Troodos highlands</strong><small>The route rises to more than 1,700 metres.</small></div></li>
            </ul>
          </article>
        </section>

        <div className="trail-divider" aria-hidden="true" />

        <section className="guide-services reveal">
          <div className="section-shell guide-services-inner">
            <div className="guide-services-heading">
              <div><p className="eyebrow">Recorded along the route</p><h2>Plan around what is known.</h2></div>
              <p>The current snapshot contains 23,107 route points. Service counts refer to named stage points, not guaranteed opening or availability across an entire section.</p>
            </div>
            <dl className="guide-service-list">
              {serviceCounts.filter(([name]) => serviceLabels[name]).map(([name, count]) => <div key={name}><dt>{serviceLabels[name]}</dt><dd><span className="sr-only">{count}</span><span aria-hidden="true" data-count-up={count}>{count}</span></dd></div>)}
            </dl>
          </div>
        </section>

        <div className="trail-divider" aria-hidden="true" />

        <section className="section-shell guide-journey reveal">
          <div className="guide-section-heading"><div><p className="eyebrow">Five points across the island</p><h2>Follow the trail, one waypoint at a time.</h2></div><a className="guide-inline-link" href="/trails/cyprus-e4/stages">View all {cyprusE4.stageCount} points <span aria-hidden="true">→</span></a></div>
          <ol className="guide-waypoint-list">
            {featuredStages.map((stage, index) => (
              <li key={stage.id}>
                <a href={`/trails/cyprus-e4/stages/${stage.id}`}>
                  <span className="guide-waypoint-dot" aria-hidden="true" />
                  <small>{index === 0 ? 'Start' : index === featuredStages.length - 1 ? 'Finish' : `${stage.accumulatedDistanceKm?.toFixed(0)} km`}</small>
                  <strong>{stage.name}</strong>
                  <span>{stage.altitudeM?.toFixed(0)} m altitude</span>
                </a>
              </li>
            ))}
          </ol>
        </section>

        <div className="trail-divider" aria-hidden="true" />

        <section className="section-shell guide-essentials reveal">
          <article className="guide-plan-copy">
            <p className="eyebrow">Shape your own walk</p>
            <h2>A route, not one fixed itinerary.</h2>
            <p>Named points give you the building blocks. Compare distance and elevation, then create walking days around your experience, daylight, accommodation and water plan.</p>
            <dl className="guide-planning-list">
              <div><dt>Choose your rhythm</dt><dd>Link short or long sections instead of following a prescribed schedule.</dd></div>
              <div><dt>Walk either way</dt><dd>EuroTrex supports both directions; the public guide follows Pafos to Larnaka for consistency.</dd></div>
              <div><dt>Check live conditions</dt><dd>Use current local advice for weather, closures, water and transport before setting out.</dd></div>
            </dl>
          </article>
          <aside className="guide-safety-panel">
            <p className="eyebrow light">Before you walk</p>
            <h2>Check the present, not only the plan.</h2>
            <ul role="list">
              <li><span>01</span>Confirm official access advice and weather.</li>
              <li><span>02</span>Carry enough water for changing conditions.</li>
              <li><span>03</span>Download trail data before limited coverage.</li>
              <li><span>04</span>Share your route and expected finish.</li>
            </ul>
            <div className="guide-emergency"><small>Emergency in Cyprus</small><strong>112</strong></div>
          </aside>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
