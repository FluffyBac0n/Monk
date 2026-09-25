import Image from 'next/image';
import type { Metadata } from 'next';
import { InterestForm } from '@/components/InterestForm';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Get involved',
  description: 'Volunteer, join field walks, collaborate or support the EuroTrex Cyprus E4 project.',
  alternates: { canonical: '/get-involved' },
  openGraph: {
    type: 'website',
    url: '/get-involved',
    title: 'Get involved with EuroTrex',
    description: 'Volunteer, join field walks, collaborate or support more dependable long-distance trail guides.',
    images: [{ url: '/involved-volunteer.webp', width: 1000, height: 750, alt: 'A volunteer recording and refreshing a trail waymark' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Get involved with EuroTrex',
    description: 'Volunteer, join field walks, collaborate or support more dependable long-distance trail guides.',
    images: ['/involved-volunteer.webp'],
  },
};

const validInterests = new Set(['volunteer', 'collaborate', 'field-walks', 'sponsor', 'host', 'other']);

export default async function GetInvolved({ searchParams }: { searchParams: Promise<{ interest?: string }> }) {
  const { interest } = await searchParams;
  const defaultInterest = interest && validInterests.has(interest) ? interest : 'volunteer';

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page get-involved-page" tabIndex={-1} {...publicHtmxNavigation}>
        <header className="get-involved-hero">
          <div className="section-shell get-involved-hero-grid">
            <div className="get-involved-hero-copy">
              <p className="eyebrow">Get involved</p>
              <h1>Make the trail more useful.</h1>
              <p>Local knowledge, careful field notes and thoughtful collaborations help EuroTrex turn a line on a map into a dependable journey.</p>
            </div>
            <figure className="get-involved-hero-image">
              <Image src="/involved-volunteer.webp" alt="A volunteer recording and refreshing a trail waymark" fill priority sizes="(max-width: 900px) 100vw, 54vw" />
              <div aria-hidden="true" />
              <figcaption>Field checks · Local knowledge</figcaption>
            </figure>
          </div>
        </header>
        <div className="trail-divider" aria-hidden="true" />
        <section className="section-shell involvement-options">
          <article><span aria-hidden="true">01</span><h2>Volunteer</h2><p>Help check trail information, services and practical details. Tell us where you are based and what you know well.</p></article>
          <article><span aria-hidden="true">02</span><h2>Collaborate</h2><p>Connect a community, public body, trail organisation or responsible-tourism initiative with the project.</p></article>
          <article><span aria-hidden="true">03</span><h2>Walk with us</h2><p>Join a field walk, report what has changed and help document the trail from a hiker’s perspective.</p></article>
        </section>
        <div className="trail-divider" aria-hidden="true" />
        <section className="form-page-section">
          <div className="section-shell form-page-grid"><div><p className="eyebrow">Tell us where you fit</p><h2>Start one useful conversation.</h2><p>Choose the closest interest and add enough context for the right person to reply. We will only use your details for this enquiry and relevant EuroTrex updates you consent to.</p><a className="simple-link" href="/partnerships">Looking for sponsorship information? <span aria-hidden="true">→</span></a></div><InterestForm kind="involved" defaultInterest={defaultInterest} /></div>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
