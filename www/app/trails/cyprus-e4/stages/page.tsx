import type { Metadata } from 'next';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { StageDirectory } from '@/components/StageDirectory';
import { getPublicTrail } from '@/lib/public-trail-data';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Cyprus-E4 stage points',
  description:
    'Browse named Cyprus-E4 stage points with distance, elevation and recorded services from the trail database.',
  alternates: { canonical: '/trails/cyprus-e4/stages' },
};

export default async function CyprusE4Stages() {
  const trail = await getPublicTrail().catch(() => null);
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
          <header className="simple-page-header section-shell">
            <p className="eyebrow">Cyprus-E4</p>
            <h1>Find your next point.</h1>
            <p>
              {trail
                ? `${trail.stages.length} reference locations, not prescribed walking days. Browse from ${trail.stages[0].name} to ${trail.stages.at(-1)!.name}; distances describe the route from the previous point.`
                : 'Trail information could not be refreshed. Please try again.'}
            </p>
          </header>
          <div className="section-shell">
            {trail ? (
              <StageDirectory stages={trail.stages} />
            ) : (
              <a
                className="button button-primary"
                href="/trails/cyprus-e4/stages"
              >
                Retry trail points
              </a>
            )}
          </div>
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
