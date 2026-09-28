import Image from 'next/image';
import type { Metadata } from 'next';
import { InterestForm } from '@/components/InterestForm';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Partnerships and sponsorship',
  description: 'Partner with EuroTrex to support practical, responsible access to the Cyprus E4 and future European long-distance trails.',
  alternates: { canonical: '/partnerships' },
  openGraph: {
    type: 'website',
    url: '/partnerships',
    title: 'Partnerships and sponsorship | EuroTrex',
    description: 'Support dependable trail information, responsible access and local value with EuroTrex.',
    images: [{ url: '/sponsors-path.webp', width: 1200, height: 800, alt: 'A hiker preparing beside a marked Cyprus trail' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Partnerships and sponsorship | EuroTrex',
    description: 'Support dependable trail information, responsible access and local value with EuroTrex.',
    images: ['/sponsors-path.webp'],
  },
};

export default function Partnerships() {
  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page get-involved-page partnerships-page" tabIndex={-1} {...publicHtmxNavigation}>
        <header className="get-involved-hero">
          <div className="section-shell get-involved-hero-grid">
            <div className="get-involved-hero-copy">
              <p className="eyebrow">For sponsors and collaborators</p>
              <h1>Support the path, not the noise.</h1>
              <p>Useful partnerships can improve route information, field verification, accessibility and the practical experience around Europe’s long-distance trails.</p>
            </div>
            <figure className="get-involved-hero-image partnerships-hero-image">
              <Image src="/sponsors-path.webp" alt="A hiker preparing beside a marked Cyprus trail" fill priority sizes="(max-width: 900px) 100vw, 54vw" />
              <div aria-hidden="true" />
              <figcaption>Trail support · Responsible access</figcaption>
            </figure>
          </div>
        </header>
        <div className="trail-divider" aria-hidden="true" />
        <section className="section-shell partnership-principles">
          <div><p className="eyebrow">A considered fit</p><h2>Partnerships should help hikers.</h2><p>EuroTrex is looking for support that makes long-distance walking clearer, safer and more welcoming—without turning the trail into an advertising surface.</p></div>
          <dl><div><dt>Trail data</dt><dd>Support field checks, route updates and practical information.</dd></div><div><dt>Access</dt><dd>Help more people prepare well and walk responsibly.</dd></div><div><dt>Local value</dt><dd>Strengthen connections with communities and trail-side services.</dd></div><div><dt>Responsible gear</dt><dd>Provide relevant equipment or expertise with clear disclosure.</dd></div></dl>
        </section>
        <div className="trail-divider" aria-hidden="true" />
        <section className="form-page-section"><div className="section-shell form-page-grid"><div><p className="eyebrow">Partnership enquiry</p><h2>Tell us what you can bring to the route.</h2><p>Share the organisation, proposed contribution and intended outcome. EuroTrex reviews fit, usefulness and transparency before discussing any activation.</p></div><InterestForm kind="involved" defaultInterest="sponsor" /></div></section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
