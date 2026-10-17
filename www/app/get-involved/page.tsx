import type { Metadata } from 'next';
import { EditorialPage } from '@/components/EditorialPage';
import { InterestForm } from '@/components/InterestForm';
import { websiteCopy } from '@/lib/website-copy';
import { getPublicTrail } from '@/lib/public-trail-data';

export const metadata: Metadata = {
  title: 'Community & Support',
  description: websiteCopy.community.introduction,
  alternates: { canonical: '/get-involved' },
};
const copy = websiteCopy.community;
const interests = new Set([
  'volunteer',
  'collaborate',
  'field-walks',
  'sponsor',
  'host',
  'other',
  'report',
  'donate',
  'work',
  'member',
  'partner-host',
  'premium-host',
  'friend-of-the-path',
]);

export default async function Community({
  searchParams,
}: {
  searchParams: Promise<{ interest?: string; point?: string }>;
}) {
  const params = await searchParams;
  const interest = interests.has(params.interest || '')
    ? params.interest!
    : 'field-walks';
  const stage = params.point
    ? (await getPublicTrail().catch(() => null))?.stages.find(
        (point) => point.id === params.point
      )
    : undefined;
  const message = stage
    ? `Trail: Cyprus-E4\nStage point: ${stage.name}\nStage ID: ${stage.id}\n\nWhat needs updating?\n`
    : interest === 'work'
      ? 'Please let me know about future work and volunteer openings.'
      : '';
  return (
    <EditorialPage
      eyebrow="Community & Support"
      title="Walk with us."
      introduction={copy.introduction}
      image="/cyprus-e4-hermit-1280.webp"
      imageAlt="A quiet landscape along the Cyprus trail"
    >
      <nav
        className="section-shell editorial-subnav"
        aria-label="Community sections"
      >
        <a href="#walk-with-us">Walk With Us</a>
        <a href="#opportunities">Work With Us &amp; Volunteer</a>
        <a href="#collaborate">Collaborate &amp; Partner</a>
        <a href="#support">Donate &amp; Sponsor</a>
      </nav>
      <section className="section-shell" id="walk-with-us">
        <div className="editorial-split">
          <div>
            <p className="eyebrow">Join Our Mapping Expeditions</p>
            <h2>
              Our Trail Philosophy
              <br />
              and Pace
            </h2>
            <p>{copy.paceIntroduction}</p>
          </div>
          <dl className="community-principles">
            {copy.pace.map(([title, text]) => (
              <div key={title}>
                <dt>{title}</dt>
                <dd>{text}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>
      <section className="section-shell expedition-section" id="expeditions">
        <h2 className="section-title">Upcoming Expeditions</h2>
        <p>{copy.schedule}</p>
        <div className="expedition-list">
          {['Cyprus', 'Crete', 'Peloponnese'].map((place) => (
            <div key={place}>
              <strong>{place}</strong>
              <span>E4 Trail</span>
              <span className="status">Coming Soon</span>
            </div>
          ))}
        </div>
        <a
          className="button button-primary"
          href="/get-involved?interest=field-walks#interest-form"
        >
          Register interest in walking with us
        </a>
      </section>
      <section className="section-shell editorial-split" id="opportunities">
        <div>
          <p className="eyebrow">Work With Us &amp; Volunteer</p>
          <h2>
            Bring your skills
            <br />
            to the trail.
          </h2>
        </div>
        <div>
          <p>
            <strong>{copy.noOpenings}</strong>
          </p>
          <p>{copy.opportunities}</p>
          <div className="editorial-actions">
            <a
              className="button button-secondary"
              href="/get-involved?interest=volunteer#interest-form"
            >
              Apply to Volunteer
            </a>
            <a
              className="button button-primary"
              href="/get-involved?interest=work#interest-form"
            >
              Join the mailing list
            </a>
          </div>
        </div>
      </section>
      <section className="section-shell editorial-split" id="collaborate">
        <div>
          <p className="eyebrow">Collaborate &amp; Partner</p>
          <h2>
            Connect your community
            <br />
            with the path.
          </h2>
        </div>
        <div>
          <p>
            Share your local knowledge, help with regional trail data
            collection, or ask about working together.
          </p>
          <a
            className="simple-link"
            href="/get-involved?interest=collaborate#interest-form"
          >
            Start a collaboration →
          </a>
        </div>
      </section>
      <section className="section-shell editorial-split" id="support">
        <div>
          <p className="eyebrow">Donate &amp; Sponsor</p>
          <h2>Support Our Vision</h2>
        </div>
        <div>
          <p>{websiteCopy.home.support}</p>
          <p>
            Tell us how you would like to contribute. We will discuss the
            arrangements with you directly; no payment is taken here.
          </p>
          <div className="editorial-actions">
            <a
              className="button button-primary"
              href="/get-involved?interest=donate#interest-form"
            >
              Enquire about supporting Eurotrex
            </a>
            <a className="simple-link" href="/partnerships">
              Become a Sponsor →
            </a>
          </div>
        </div>
      </section>
      <section
        className="section-shell form-page-grid programme-enquiry"
        id="interest-form"
      >
        <div>
          <p className="eyebrow">Your part in the journey</p>
          <h2>
            {stage
              ? `Report an issue at ${stage.name}.`
              : 'Let’s hear from you.'}
          </h2>
          <p>
            Tell us where you are based and how you would like to help. We
            review enquiries and reply by email.
          </p>
        </div>
        <div className="enquiry-panel">
          <InterestForm
            kind="involved"
            defaultInterest={interest}
            defaultMessage={message}
          />
        </div>
      </section>
    </EditorialPage>
  );
}
