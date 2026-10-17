import Image from 'next/image';
import type { Metadata } from 'next';
import { EditorialPage } from '@/components/EditorialPage';
import { websiteCopy } from '@/lib/website-copy';

export const metadata: Metadata = {
  title: 'The Eurotrex Initiative',
  description: websiteCopy.initiative.introduction,
  alternates: { canonical: '/about' },
};
const copy = websiteCopy.initiative;

export default function About() {
  return (
    <EditorialPage
      pageClass="initiative-page"
      hero={
        <header className="initiative-vision">
          <Image
            src="/cyprus-e4-forest-1200.webp"
            alt="Mountains and forest along the Cyprus E4"
            fill
            priority
            sizes="100vw"
          />
          <div className="initiative-vision-copy section-shell">
            <p className="eyebrow">The Eurotrex Initiative</p>
            <h1>
              Discover Europe,
              <br />
              One Path at a Time
            </h1>
            <p>{copy.introduction}</p>
            <p>{copy.guide}</p>
            <strong>{copy.closing}</strong>
          </div>
        </header>
      }
    >
      <section className="section-shell initiative-origin">
        <figure>
          <Image
            src="/involved-walk.webp"
            alt="Hikers sharing a walk along the trail"
            fill
            sizes="(max-width: 760px) 100vw, 50vw"
          />
        </figure>
        <div>
          <h2>
            Built by Hikers,
            <br />
            for Hikers
          </h2>
          <p>{copy.origin}</p>
          <p>{copy.experience}</p>
        </div>
      </section>
      <section className="initiative-phase-band">
        <div className="section-shell initiative-phases">
          <h2>Project Phases</h2>
          <ol>
            {copy.phases.map((phase, index) => (
              <li key={phase.title}>
                <span>Phase {index + 1}</span>
                <h3>{phase.title}</h3>
                <p>{phase.text}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>
      <section className="section-shell foundation-section initiative-foundation">
        <h2>Current Project Focus</h2>
        <h3>Our Foundation: The E4 Cyprus Trail</h3>
        <p>{copy.focus}</p>
        <a className="simple-link" href="/trails/cyprus-e4">
          Explore the E4 Cyprus Trail →
        </a>
      </section>
      <section className="section-shell initiative-funding">
        <h2>
          Co-funded by
          <br />
          the European Union &amp; Republic of Cyprus
        </h2>
        <p>{copy.funding}</p>
        <p>{copy.investment}</p>
        <a
          className="button button-secondary"
          href="https://thalia.com.cy/en/home-en/"
          target="_blank"
          rel="noopener noreferrer"
        >
          Learn More About the THALIA Programme ↗
        </a>
      </section>
      <section className="section-shell initiative-team">
        <h2 className="section-title">The Team</h2>
        <div className="team-grid">
          <article className="team-member">
            <Image
              className="team-photo"
              src="/team-petros-christofides.webp"
              alt="Petros Christofides overlooking the Cyprus coastline"
              width={960}
              height={720}
              sizes="(max-width: 760px) 100vw, 45vw"
            />
            <h3>Petros Christofides</h3>
            <p>
              Petros stepped away from a career in actuarial work to embrace
              life outdoors. An experienced long-distance hiker, he has walked
              thousands of kilometres across some of Europe’s best-known trails.
              His first-hand knowledge and vision shape the foundations of
              EuroTrex.
            </p>
          </article>
          <article className="team-member">
            <Image
              className="team-photo"
              src="/team-andreas-michaelides.webp"
              alt="Andreas Michaelides with his dog on a coastal walk in Cyprus"
              width={960}
              height={720}
              sizes="(max-width: 760px) 100vw, 45vw"
            />
            <h3>Andreas Michaelides</h3>
            <p>
              Andreas is a software engineer with 15 years of experience and a
              love of nature and photography. He brings the technical expertise
              that turns their shared vision into practical tools, helping more
              people discover and explore long-distance trails.
            </p>
          </article>
        </div>
      </section>
      <section className="involved-section">
        <div className="section-shell">
          <h2 className="section-title">Join Us</h2>
          <div className="involved-grid">
            {[
              [
                'Walk with us',
                websiteCopy.community.introduction,
                'See Trail Schedule',
                '/get-involved#expeditions',
                '/involved-walk.webp',
              ],
              [
                'Volunteer',
                websiteCopy.home.volunteer,
                'Apply to Volunteer',
                '/get-involved?interest=volunteer#interest-form',
                '/involved-volunteer.webp',
              ],
              [
                'Collaborate',
                'Work with us on responsible tourism, access and regional initiatives.',
                'Start a collaboration',
                '/get-involved?interest=collaborate#interest-form',
                '/involved-collaborate.webp',
              ],
              [
                'Support the vision',
                websiteCopy.home.support,
                'Explore partnerships',
                '/partnerships',
                '/involved-support.webp',
              ],
            ].map(([title, text, label, href, image], index) => (
              <article
                className={index === 0 ? 'involved-featured' : ''}
                key={title}
              >
                <a className="involved-card-link" href={href}>
                  <div className="involved-image">
                    <Image
                      src={image}
                      alt=""
                      fill
                      sizes={
                        index === 0
                          ? '(max-width: 820px) 100vw, 58vw'
                          : '(max-width: 820px) 100vw, 36vw'
                      }
                    />
                  </div>
                  <div className="involved-card-shade" />
                  <div className="involved-card-body">
                    <h3>{title}</h3>
                    <p>{text}</p>
                    <span className="editorial-link">
                      {label}
                      <i aria-hidden="true" />
                    </span>
                  </div>
                </a>
              </article>
            ))}
          </div>
        </div>
      </section>
    </EditorialPage>
  );
}
