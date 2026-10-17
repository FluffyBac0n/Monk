import type { Metadata } from 'next';
import { EditorialPage } from '@/components/EditorialPage';
import { InterestForm } from '@/components/InterestForm';
import { websiteCopy } from '@/lib/website-copy';
import { disableHtmxNavigation } from '@/lib/htmx';

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
      eyebrow="A place along the path"
      title="Become a Host"
      introduction={websiteCopy.hosts.introduction}
      image="/hosts-path.webp"
      imageAlt="A stone guesthouse welcoming walkers near the trail"
    >
      <section className="section-shell editorial-statement">
        <h2>A warm welcome goes a long way.</h2>
        <p>{websiteCopy.home.hosts}</p>
        <div className="editorial-actions">
          <a
            className="button button-primary"
            href="/portal?mode=register"
            {...disableHtmxNavigation}
          >
            Create your host account
          </a>
          <a
            className="button button-secondary"
            href="/portal"
            {...disableHtmxNavigation}
          >
            Sign in to Host Portal
          </a>
        </div>
      </section>
      <section className="section-shell initiative-phases">
        <h2 className="section-title">How It Works</h2>
        <ol>
          <li>
            <span>01 · Your account</span>
            <h3>Introduce yourself.</h3>
            <p>
              Add your name and email, with company or organisation details if
              applicable. Verify your email, then wait for host access to be
              reviewed.
            </p>
          </li>
          <li>
            <span>02 · Your accommodation</span>
            <h3>Prepare your listing.</h3>
            <p>
              Add your location, nearest trail point, prices and contact
              details. Save a draft and preview how hikers will see it.
            </p>
          </li>
          <li>
            <span>03 · Our review</span>
            <h3>Submit for verification.</h3>
            <p>
              We review your authority to represent the accommodation, its
              contact details and trail relevance before publication. Account
              and listing reviews are separate.
            </p>
          </li>
        </ol>
      </section>
      <section className="section-shell host-verification">
        <div>
          <p className="eyebrow">What verification means</p>
          <h2>
            Clear information.
            <br />A human review.
          </h2>
          <p>
            Verified listings have been reviewed for representative authority,
            contact details and relevance to the trail. Verification is not a
            safety certification, quality rating or booking guarantee.
          </p>
        </div>
        <div>
          <h3>Why Host on Eurotrex?</h3>
          <p>
            Help hikers find a place to rest, promote your local trail and join
            a community of hosts along the path. Hikers contact and book with
            you directly.
          </p>
          <a className="simple-link" href="/partner-terms">
            Read our partner listing policy →
          </a>
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
                className="simple-link"
                href={`/become-a-host?interest=${programme.id}#enquire`}
              >
                Enquire about this programme →
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
    </EditorialPage>
  );
}
