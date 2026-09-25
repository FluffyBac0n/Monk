import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { cyprusE4, cyprusE4Stages, getCyprusE4Stage } from '@/lib/cyprus-e4-data';
import { publicHtmxNavigation } from '@/lib/htmx';
import { SITE_URL } from '@/lib/site';

type StagePageProps = { params: Promise<{ stageId: string }> };

const serviceLabels: Record<string, string> = {
  lodging: 'Stays', tent: 'Camping', food: 'Food', grocery: 'Groceries', drinkableWater: 'Drinking water', nonDrinkableWater: 'Non-drinking water', toilets: 'Toilets', medical: 'Medical help', pharmacy: 'Pharmacy', atm: 'ATM', busStop: 'Bus stop',
};

export function generateStaticParams() {
  return cyprusE4Stages.map((stage) => ({ stageId: stage.id }));
}

export async function generateMetadata({ params }: StagePageProps): Promise<Metadata> {
  const { stageId } = await params;
  const stage = getCyprusE4Stage(stageId);
  if (!stage) return {};
  return {
    title: `${stage.name} · Cyprus E4 stage point`,
    description: `${stage.name} on the Cyprus E4: distance, elevation, recorded services, transport and trail data update information.`,
    alternates: { canonical: `/trails/cyprus-e4/stages/${stage.id}` },
  };
}

export default async function CyprusE4StagePage({ params }: StagePageProps) {
  const { stageId } = await params;
  const stage = getCyprusE4Stage(stageId);
  if (!stage) notFound();
  const index = cyprusE4Stages.findIndex((row) => row.id === stage.id);
  const previous = cyprusE4Stages[index - 1];
  const next = cyprusE4Stages[index + 1];
  const services = Object.entries(stage.services).filter(([, available]) => available).map(([name]) => serviceLabels[name] || name);
  const updated = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(cyprusE4.dataUpdatedAt));
  const schema = { '@context': 'https://schema.org', '@type': 'Place', name: `${stage.name} — Cyprus E4`, url: `${SITE_URL}/trails/cyprus-e4/stages/${stage.id}`, isPartOf: { '@type': 'Route', name: 'Cyprus E4', url: `${SITE_URL}/trails/cyprus-e4` } };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page stage-page" data-trail-guide="cyprus-e4" tabIndex={-1} {...publicHtmxNavigation}>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }} />
        <header className="simple-page-header section-shell">
          <a className="stage-return-link" href="/trails/cyprus-e4/stages"><span aria-hidden="true">←</span> All stage points</a>
          <p className="eyebrow">Point {index + 1} of {cyprusE4Stages.length}</p><h1>{stage.name}</h1><p>{stage.accumulatedDistanceKm?.toFixed(1) ?? '—'} km from Pafos Airport on the published Cyprus E4 route.</p>
        </header>
        <section className="section-shell stage-detail-grid">
          <div className="stage-main">
            <dl className="stage-metrics">
              <div><dt>Segment distance</dt><dd>{stage.segmentLengthKm?.toFixed(1) ?? '—'} km</dd></div><div><dt>Ascent</dt><dd>{stage.elevationUpM?.toFixed(0) ?? '—'} m</dd></div><div><dt>Descent</dt><dd>{stage.elevationDownM?.toFixed(0) ?? '—'} m</dd></div><div><dt>Altitude</dt><dd>{stage.altitudeM?.toFixed(0) ?? '—'} m</dd></div>
            </dl>
            <article className="stage-section"><p className="eyebrow">Terrain and route</p><h2>What the current data can tell you.</h2><p>The published snapshot records distance and elevation into this point. Detailed surface and terrain notes have not yet been editorially published, so do not infer conditions from elevation alone. Use the route in the app and current local advice when planning.</p></article>
            <article className="stage-section"><p className="eyebrow">Services at this point</p><h2>{services.length ? `${services.length} recorded services.` : 'No services recorded.'}</h2>{services.length ? <ul className="service-pills">{services.map((service) => <li key={service}>{service}</li>)}</ul> : <p>No endpoint services are present in the current data. That does not prove none exist; plan conservatively.</p>}<p className="data-caveat">Service flags refer to this named point, not the entire incoming segment. Opening hours and seasonal availability are not guaranteed.</p></article>
            <article className="stage-section"><p className="eyebrow">Transport and safety</p><h2>{stage.services.busStop ? 'A bus stop is recorded here.' : 'No bus stop is recorded here.'}</h2><p>Confirm live timetables and access locally. Carry sufficient water, check weather and closures, download offline data, and share your plan. For emergencies in Cyprus, call 112.</p></article>
          </div>
          <aside className="stage-aside"><strong>Trail data updated {updated}</strong><p>This page reflects the current EuroTrex route snapshot and can lag changing ground conditions.</p></aside>
        </section>
        <nav className="section-shell stage-pagination" aria-label="Adjacent stage points">
          {previous ? <a href={`/trails/cyprus-e4/stages/${previous.id}`}><small>Previous point</small><strong>← {previous.name}</strong></a> : <span />}
          {next ? <a href={`/trails/cyprus-e4/stages/${next.id}`}><small>Next point</small><strong>{next.name} →</strong></a> : <span />}
        </nav>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
