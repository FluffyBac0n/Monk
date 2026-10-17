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
      eyebrow="The Eurotrex Initiative"
      title={copy.title}
      introduction={copy.introduction}
      image="/cyprus-e4-forest-1200.webp"
      imageAlt="A forest path along the Cyprus E4"
    >
      <section className="section-shell editorial-statement">
        <p>{copy.guide}</p>
        <h2>{copy.closing}</h2>
      </section>
      <section className="section-shell editorial-split">
        <div>
          <p className="eyebrow">Our Origin Story</p>
          <h2>
            Built by Hikers,
            <br />
            for Hikers
          </h2>
        </div>
        <div>
          <p>{copy.origin}</p>
          <p>{copy.experience}</p>
        </div>
      </section>
      <section className="section-shell initiative-phases">
        <h2 className="section-title">Project Phases</h2>
        <ol>
          {copy.phases.map((phase, index) => (
            <li key={phase.title}>
              <span>Phase {index + 1}</span>
              <h3>{phase.title}</h3>
              <p>{phase.text}</p>
            </li>
          ))}
        </ol>
      </section>
      <section className="section-shell foundation-section">
        <p className="eyebrow">Current Project Focus</p>
        <h2>
          Our Foundation:
          <br />
          The E4 Cyprus Trail
        </h2>
        <p>{copy.focus}</p>
        <a className="button button-primary" href="/trails/cyprus-e4">
          Explore the E4 Cyprus Trail
        </a>
      </section>
      <section className="section-shell editorial-split funding-section">
        <div>
          <p className="eyebrow">Supported By</p>
          <h2>Co-funded by the European Union &amp; Republic of Cyprus</h2>
        </div>
        <div>
          <p>{copy.funding}</p>
          <p>{copy.investment}</p>
          <a
            className="simple-link"
            href="https://thalia.com.cy/en/home-en/"
            target="_blank"
            rel="noopener noreferrer"
          >
            Learn More About the THALIA Programme ↗
          </a>
        </div>
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
    </EditorialPage>
  );
}
