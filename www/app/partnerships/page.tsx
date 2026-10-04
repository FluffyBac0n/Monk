import Image from 'next/image';
import type { Metadata } from 'next';
import { InterestForm } from '@/components/InterestForm';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Partnerships and sponsorship',
  description: 'Partner with EuroTrex to support practical, responsible access to the Cyprus-E4 and future European long-distance trails.',
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
              <p className="eyebrow">Partnerships</p>
              <h1>Support the trail.</h1>
              <p>Bring equipment, expertise or funding to field checks, better trail information and stronger local connections.</p>
              <a className="button button-primary fill-link partnership-enquiry-link" href="#partnership-enquiry"><span>Discuss a partnership</span></a>
            </div>
            <figure className="get-involved-hero-image partnerships-hero-image">
              <Image src="/sponsors-path.webp" alt="A hiker preparing beside a marked Cyprus trail" fill priority sizes="(max-width: 600px) calc(100vw - 40px), (max-width: 900px) 36vw, 440px" />
            </figure>
          </div>
        </header>
        <section className="form-page-section" aria-labelledby="partnership-support-title">
          <div className="section-shell form-page-grid">
            <div className="partnership-principles">
              <h2 id="partnership-support-title">Where you can help.</h2>
              <dl><div><dt>Trail information</dt><dd>Field checks, route updates and practical details.</dd></div><div><dt>Access</dt><dd>Help hikers prepare well and walk responsibly.</dd></div><div><dt>Local communities</dt><dd>Connect hikers with people and services along the trail.</dd></div><div><dt>Equipment & expertise</dt><dd>Useful gear and knowledge for work in the field.</dd></div></dl>
              <p>We agree the contribution, recognition and reporting together before work begins.</p>
              <a className="simple-link" href="/partner-terms">Read our partner policy <span aria-hidden="true">→</span></a>
            </div>
            <div id="partnership-enquiry" className="enquiry-panel">
              <h2>Let’s work together.</h2>
              <p>Tell us about your organisation, what you can contribute and where you would like to help.</p>
              <InterestForm kind="involved" defaultInterest="sponsor" partnership />
              <p className="enquiry-note">We reply by email. Partnership acceptance, audience reach and advertising placement are not guaranteed.</p>
            </div>
          </div>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
