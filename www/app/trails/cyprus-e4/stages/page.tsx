import type { Metadata } from 'next';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { StageDirectory } from '@/components/StageDirectory';
import { cyprusE4Stages } from '@/lib/cyprus-e4-data';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Cyprus E4 stages and named points',
  description: 'Browse all 123 named Cyprus E4 stage points with distance, elevation and recorded services.',
  alternates: { canonical: '/trails/cyprus-e4/stages' },
};

export default function CyprusE4Stages() {
  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page" tabIndex={-1} {...publicHtmxNavigation}>
        <header className="simple-page-header section-shell"><nav className="breadcrumbs" aria-label="Breadcrumb"><a href="/">Home</a><span aria-hidden="true">/</span><a href="/trails/cyprus-e4">Cyprus E4</a><span aria-hidden="true">/</span><span>Stage points</span></nav><p className="eyebrow">Cyprus E4</p><h1>Stages and named points.</h1><p>Browse the public trail snapshot from Pafos Airport to Larnaka Airport. Segment metrics describe the route into each point.</p></header>
        <div className="section-shell"><StageDirectory stages={cyprusE4Stages} /></div>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
