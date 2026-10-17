import Image from 'next/image';
import { HostAccount } from '@/components/HostAccount';
import type { Metadata } from 'next';
import { EditorialPage } from '@/components/EditorialPage';
import { InterestForm } from '@/components/InterestForm';
import { websiteCopy } from '@/lib/website-copy';

export const metadata: Metadata = {
  title: 'Become a Host',
  description: websiteCopy.home.hosts,
  alternates: { canonical: '/become-a-host' },
};
const allowedInterests = new Set([
  'host',
  'partner-host',
  'premium-host',
  'friend-of-the-path',
  'member',
]);

export default async function BecomeHost({
  searchParams,
}: {
  searchParams: Promise<{ interest?: string }>;
}) {
  const params = await searchParams;
  const interest = allowedInterests.has(params.interest || '')
    ? params.interest
    : 'host';
  return (
    <EditorialPage
      pageClass="host-landing-page"
      clientNavigation
      hero={
        <header className="section-shell host-welcome">
          <div>
            <h1>
              Become a<br />
              Host
            </h1>
            <p className="host-emotional-copy">
              One of the main priorities of the long-distance hiker is to find a
              suitable restful shelter to spend the night after a long day on
              the trail. That is why we consider hosts to be an invaluable part
              of the trail community. If you want to be part of this community
              and let hikers know about your shelter, create an account to
              upload details of your accommodation.
            </p>
            <p>{websiteCopy.hosts.introduction}</p>
          </div>
          <figure>
            <Image
              src="/hosts-path.webp"
              alt="A welcoming guesthouse along the trail"
              fill
              priority
              sizes="(max-width: 760px) 100vw, 50vw"
            />
          </figure>
        </header>
      }
    >
      <section className="host-section">
        <div className="section-shell">
          <h2 className="section-title">How It Works</h2>
          <ol className="host-steps">
            {[
              [
                'Create your host account',
                'Add your name and verify your email. Company or organisation details are optional. We review your request before activating host access.',
                '/host-step-account-photo.webp',
                'A guesthouse owner creating an account on a laptop',
              ],
              [
                'Prepare your listing',
                'Once approved, add your location, nearest trail point, prices and contact details. Save a draft and preview the app card.',
                '/host-step-details-photo.webp',
                'A host checking accommodation details',
              ],
              [
                'Submit for verification',
                'We review representative authority, contact details and trail relevance before publication. Account and listing reviews are separate.',
                '/host-step-verified-photo.webp',
                'A hiker finding a guesthouse along the trail',
              ],
            ].map(([title, text, image, alt]) => (
              <li className="host-moment" key={title}>
                <div className="host-step-image">
                  <Image
                    src={image}
                    alt={alt}
                    fill
                    sizes="(max-width: 760px) 100vw, 31vw"
                  />
                </div>
                <div className="host-step-body">
                  <h3>{title}</h3>
                  <p>{text}</p>
                </div>
              </li>
            ))}
          </ol>
        </div>
      </section>
      <section className="host-benefits-band">
        <div className="section-shell">
          <h2>Why Host on Eurotrex?</h2>
          <div className="host-benefits-grid">
            {[
              [
                'Help Hikers',
                'Welcome tired walkers to your doorstep, provide vital trail shelter, and increase your local booking traffic.',
                'lodging',
              ],
              [
                'Promote Trails',
                'Put your local trails and village on the map and attract a respectful community of eco-tourists and hikers.',
                'trail',
              ],
              [
                'Community Access',
                'Join a network of European hosts, build regional hospitality insight, and co-build the future of E-path tourism.',
                'community',
              ],
            ].map(([title, text, icon]) => (
              <article key={title}>
                <span
                  className={`host-benefit-icon ${icon}`}
                  aria-hidden="true"
                >
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.4"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  >
                    <path
                      d={
                        icon === 'lodging'
                          ? 'M7 3h6v9l6 3v5H4v-5h3V3Zm0 5h6M4 17h15M10 5h3M10 8h3'
                          : icon === 'trail'
                            ? 'm2 19 7-11 4 6 3-4 6 9H2Zm5-8 2 2 2-2M5 22c6-5 9 1 14-3'
                            : 'M12 8v8M8 12h8M5 5l3 3m8 8 3 3M5 19l3-3m8-8 3-3M10 3h4v3h-4V3Zm0 15h4v3h-4v-3ZM3 10h3v4H3v-4Zm15 0h3v4h-3v-4Z'
                      }
                    />
                  </svg>
                </span>
                <h3>{title}</h3>
                <p>{text}</p>
              </article>
            ))}
          </div>
          <div className="host-badge-explanation">
            <span className="verified-stay">Eurotrex Verified Stay</span>
            <p>
              Verified listings are reviewed for representative authority,
              contact details and trail relevance. Verification is not a safety
              certification, quality rating or booking guarantee.
            </p>
            <a
              className="button button-secondary cta-button"
              href="/partner-terms"
            >
              Read our partner listing policy
            </a>
          </div>
        </div>
      </section>
      <section className="section-shell host-account-section" id="host-account">
        <HostAccount />
      </section>
      <section className="section-shell faq-section">
        <h2 className="section-title">Host Questions</h2>
        <div className="faq-list">
          <details>
            <summary>Can I register without a company?</summary>
            <p>
              Yes. Hosts can be individuals or representatives of businesses,
              organisations and public bodies. Company or organisation name is
              optional.
            </p>
          </details>
          <details>
            <summary>
              Does creating an account publish my accommodation?
            </summary>
            <p>
              No. Verify your email and wait for host access to be activated,
              then prepare and submit a listing for its own review.
            </p>
          </details>
          <details>
            <summary>Are sponsorship and verification the same?</summary>
            <p>
              No. Sponsorship concerns programme participation and promotion.
              Listing verification follows the review described above.
            </p>
          </details>
          <details>
            <summary>What happens when I change a published listing?</summary>
            <p>
              Your current listing remains visible while the proposed update is
              reviewed. You can follow its status in the Host Portal.
            </p>
          </details>
        </div>
      </section>
      <section className="section-shell host-programmes" id="programmes">
        <p className="eyebrow">Programme enquiries</p>
        <h2>Find your place in the community.</h2>
        <p className="section-introduction">
          We are taking enquiries about the following programmes. We will
          confirm eligibility, benefits and arrangements with you before
          participation; this page does not collect payments or activate
          memberships.
        </p>
        <div className="programme-grid">
          {websiteCopy.hosts.programmes.map((programme) => (
            <article key={programme.id}>
              <h3>{programme.title}</h3>
              <p>{programme.text}</p>
              <a
                className="button button-secondary cta-button"
                href={`/become-a-host?interest=${programme.id}#enquire`}
              >
                Enquire about this programme
              </a>
            </article>
          ))}
        </div>
      </section>
      <section
        className="section-shell form-page-grid programme-enquiry"
        id="enquire"
      >
        <div>
          <p className="eyebrow">Let’s talk</p>
          <h2>
            Tell us where
            <br />
            you fit in.
          </h2>
          <p>
            Ask about listing your accommodation, joining a host programme or
            becoming a Member.
          </p>
        </div>
        <div className="enquiry-panel">
          <InterestForm kind="involved" defaultInterest={interest} />
        </div>
      </section>
    </EditorialPage>
  );
}
