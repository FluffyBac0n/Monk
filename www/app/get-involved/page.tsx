import Image from 'next/image';
import type { Metadata } from 'next';
import { InterestForm } from '@/components/InterestForm';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { disableHtmxNavigation, publicHtmxNavigation } from '@/lib/htmx';
import { getCyprusE4Stage } from '@/lib/cyprus-e4-data';

export const metadata: Metadata = {
  title: 'Join us',
  description: 'Volunteer, join field walks, collaborate or support the EuroTrex Cyprus-E4 project.',
  alternates: { canonical: '/get-involved' },
  openGraph: {
    type: 'website',
    url: '/get-involved',
    title: 'Join EuroTrex',
    description: 'Volunteer, join field walks, collaborate or support more dependable long-distance trail guides.',
    images: [{ url: '/involved-volunteer.webp', width: 1000, height: 750, alt: 'A volunteer recording and refreshing a trail waymark' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Join EuroTrex',
    description: 'Volunteer, join field walks, collaborate or support more dependable long-distance trail guides.',
    images: ['/involved-volunteer.webp'],
  },
};

const validInterests = new Set(['volunteer', 'collaborate', 'field-walks', 'sponsor', 'host', 'other', 'report']);
const participation = [
  { interest: 'volunteer', title: 'Volunteer', copy: 'Check trail details and share your local knowledge.' },
  { interest: 'collaborate', title: 'Collaborate', copy: 'Connect your community or organisation with the project.' },
  { interest: 'field-walks', title: 'Walk with us', copy: 'Register your interest in future field walks.' },
];

export default async function GetInvolved({ searchParams }: { searchParams: Promise<{ interest?: string; point?: string }> }) {
  const { interest, point } = await searchParams;
  const defaultInterest = interest && validInterests.has(interest) ? interest : 'volunteer';
  const stage = point ? getCyprusE4Stage(point) : undefined;
  const defaultMessage = stage ? `Trail: Cyprus-E4\nStage point: ${stage.name}\nPage: /trails/cyprus-e4/stages/${stage.id}\n\nWhat has changed?\n` : '';

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="content-page get-involved-page" tabIndex={-1} {...publicHtmxNavigation}>
        <header className="get-involved-hero">
          <div className="section-shell get-involved-hero-grid">
            <div className="get-involved-hero-copy">
              <p className="eyebrow">Join us</p>
              <h1>Make a difference<br />on the trail.</h1>
              <p>Share what you know, lend a hand or walk with us. Help make Cyprus-E4 more useful for everyone.</p>
            </div>
            <figure className="get-involved-hero-image">
              <Image src="/involved-volunteer.webp" alt="A volunteer recording and refreshing a trail waymark" fill priority sizes="(max-width: 600px) calc(100vw - 40px), (max-width: 900px) 36vw, 440px" />
            </figure>
          </div>
        </header>
        <section className="form-page-section" aria-labelledby="participation-title">
          <div className="section-shell form-page-grid">
            <div>
              <h2 id="participation-title">Ways to help.</h2>
              <nav className="participation-options" aria-label="Choose how to take part">
                {participation.map(({ interest: value, title, copy }) => (
                  <a key={value} href={`/get-involved?interest=${value}#interest-form`} data-interest-choice={value} aria-controls="interest-form" aria-current={defaultInterest === value ? 'true' : undefined} {...disableHtmxNavigation}>
                    <div><h3>{title}</h3><p>{copy}</p></div>
                    <span data-interest-choice-label>{defaultInterest === value ? 'Selected' : 'Choose →'}</span>
                  </a>
                ))}
              </nav>
              <p className="participation-note">Field-walk dates and places are confirmed separately.</p>
              <a className="simple-link" href="/partnerships">Looking to sponsor the project? <span aria-hidden="true">→</span></a>
            </div>
            <div id="interest-form" className="enquiry-panel">
              <h2>{stage ? `Report an issue at ${stage.name}.` : 'Let’s hear from you.'}</h2>
              <p>Tell us where you are based and how you would like to help. We review enquiries and reply by email.</p>
              <InterestForm kind="involved" defaultInterest={defaultInterest} defaultMessage={defaultMessage} />
              <p className="enquiry-note">Response times vary during private testing.</p>
            </div>
          </div>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
