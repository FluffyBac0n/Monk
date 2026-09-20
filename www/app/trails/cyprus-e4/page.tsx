import type { Metadata } from 'next';
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
  lodging: 'lodging', tent: 'camping', food: 'food', grocery: 'groceries', drinkableWater: 'drinking water', toilets: 'toilets', medical: 'medical help', pharmacy: 'pharmacies', atm: 'ATMs', busStop: 'bus stops',
};

export default function CyprusE4Overview() {
  const updated = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(cyprusE4.dataUpdatedAt));
  const schema = {
    '@context': 'https://schema.org', '@type': 'Route', name: 'Cyprus E4', url: `${SITE_URL}/trails/cyprus-e4`,
    description: 'A long-distance hiking route across Cyprus from Pafos Airport to Larnaka Airport.',
  };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page" tabIndex={-1} {...publicHtmxNavigation}>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
        <header className="content-hero trail-guide-hero">
          <div className="section-shell content-hero-inner">
            <nav className="breadcrumbs" aria-label="Breadcrumb"><a href="/">Home</a><span aria-hidden="true">/</span><span>Cyprus E4</span></nav>
            <p className="eyebrow light">Public trail guide</p>
            <h1>Cyprus E4</h1>
            <p>From Pafos Airport to Larnaka Airport across coast, forest and the Troodos mountains.</p>
            <div className="hero-actions"><a className="button button-yellow" href="/trails/cyprus-e4/stages">Browse all stage points</a></div>
          </div>
        </header>

        <section className="section-shell route-overview">
          <dl className="route-stat-grid">
            <div><dt>Total distance</dt><dd>{cyprusE4.distanceKm.toFixed(1)} km</dd></div>
            <div><dt>Named stage points</dt><dd>{cyprusE4.stageCount}</dd></div>
            <div><dt>Route high point</dt><dd>{Math.round(cyprusE4.highPointM).toLocaleString('en-GB')} m</dd></div>
            <div><dt>Direction</dt><dd>Pafos ↔ Larnaka</dd></div>
          </dl>
          <div className="route-copy-grid">
            <article><p className="eyebrow">What is published</p><h2>Practical facts before the app opens.</h2><p>Each stage page lists segment and cumulative distance, ascent, descent, altitude and services recorded at that named point. This public guide is intentionally factual and indexable.</p></article>
            <aside className="data-note"><strong>Trail data updated {updated}</strong><p>The current snapshot contains 23,107 route points. Conditions can change after publication, so confirm weather, closures, water and transport locally before walking.</p></aside>
          </div>
        </section>

        <section className="route-services">
          <div className="section-shell">
            <div className="section-heading"><div><p className="eyebrow">Recorded services</p><h2>Plan around what is known.</h2></div><p>Counts show named stage points where each service is recorded—not guaranteed opening or availability along the whole segment.</p></div>
            <dl className="service-count-grid">
              {serviceCounts.filter(([name]) => serviceLabels[name]).map(([name, count]) => <div key={name}><dt>{serviceLabels[name]}</dt><dd>{count}</dd></div>)}
            </dl>
          </div>
        </section>

        <section className="section-shell guide-split">
          <article><p className="eyebrow">What to expect</p><h2>A long route, not one fixed itinerary.</h2><p>The catalog records named points rather than prescribing a daily schedule. Use segment distances and elevation to shape walking days that fit your experience, daylight, accommodation and water plan.</p><p>EuroTrex supports both directions. The public pages follow Pafos to Larnaka for consistency.</p></article>
          <article className="safety-card"><p className="eyebrow">Safety baseline</p><h3>Check the present, not only the plan.</h3><ul><li>Confirm official access advice and weather before departure.</li><li>Carry enough water and do not assume a recorded service is open.</li><li>Download offline trail data before entering limited-coverage areas.</li><li>Share your plan and know the emergency number for Cyprus: 112.</li></ul></article>
        </section>

        <section className="section-shell stage-preview">
          <div className="section-heading"><div><p className="eyebrow">Along the way</p><h2>Start with a named stage point.</h2></div><a className="simple-link" href="/trails/cyprus-e4/stages">View all {cyprusE4.stageCount} points <span aria-hidden="true">→</span></a></div>
          <div className="stage-preview-grid">
            {[cyprusE4Stages[0], cyprusE4Stages[30], cyprusE4Stages[61], cyprusE4Stages[92], cyprusE4Stages[122]].map((stage) => <a key={stage.id} href={`/trails/cyprus-e4/stages/${stage.id}`}><small>{stage.accumulatedDistanceKm?.toFixed(1)} km</small><strong>{stage.name}</strong><span>{stage.altitudeM?.toFixed(0)} m altitude <b aria-hidden="true">→</b></span></a>)}
          </div>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
