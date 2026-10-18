import { TrailDivider } from '@/components/TrailDivider';
import Image from 'next/image';
import { PublicContent } from '@/components/PublicContent';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicFooter } from '@/components/PublicFooter';
import { AppDownload } from '@/components/AppDownload';
import { websiteCopy } from '@/lib/website-copy';
import { publicHtmxNavigation } from '@/lib/htmx';

const copy = websiteCopy.home;
const paths = [
  {
    title: 'For Hikers',
    copy: copy.hikers,
    image: '/cyprus-e4-forest-960.webp',
    alt: 'A marked forest path in Cyprus',
    action: 'Get the Eurotrex E4 App',
    href: '/trails/cyprus-e4#app',
  },
  {
    title: 'For Hosts',
    copy: copy.hosts,
    image: '/hosts-path.webp',
    alt: 'A welcoming stone guesthouse near a hiking trail',
    action: 'Become a Certified Host',
    href: '/become-a-host',
  },
  {
    title: 'For Sponsors',
    copy: copy.sponsors,
    image: '/sponsors-path.webp',
    alt: 'A hiker preparing equipment beside the trail',
    action: 'Become a Sponsor',
    href: '/partnerships',
  },
];
const involvement = [
  [
    'Volunteer',
    copy.volunteer,
    'Apply to Volunteer',
    '/get-involved?interest=volunteer#interest-form',
  ],
  ['Work With Us', copy.work, 'View Openings', '/get-involved#opportunities'],
  [
    'Walk With Us',
    copy.walk,
    'See Trail Schedule',
    '/get-involved#expeditions',
  ],
  [
    'Support Our Vision',
    copy.support,
    'Donate to Eurotrex',
    '/get-involved?interest=donate#support',
  ],
];

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <PublicHeader />
      <PublicContent>
        <main id="main-content" tabIndex={-1} {...publicHtmxNavigation}>
          <div className="hero-banner">
            <div className="hero-media">
              <picture>
                <source
                  srcSet="/zapalo-coast-hero-640.webp 640w, /zapalo-coast-hero-960.webp 960w, /zapalo-coast-hero-1280.webp 1280w, /zapalo-coast-hero-1920.webp 1920w"
                  sizes="100vw"
                  type="image/webp"
                />
                <img
                  className="hero-image"
                  src="/zapalo-coast-hero-1280.webp"
                  alt="Limestone cliffs and the Mediterranean at Zapalo Bay in Cyprus"
                  decoding="async"
                  fetchPriority="high"
                />
              </picture>
            </div>
            <div className="hero-shade" />
            <section className="hero">
              <div className="hero-inner">
                <div className="hero-content">
                  <h1>
                    Find your way
                    <br />
                    with Eurotrex.
                  </h1>
                  <p className="hero-copy">{copy.introduction}</p>
                  <div className="hero-actions">
                    <a
                      className="button button-outline fill-link"
                      href="/trails/cyprus-e4"
                    >
                      Explore the E4 Cyprus Trail
                    </a>
                  </div>
                </div>
              </div>
            </section>
            <AppDownload id="hero-app" />
          </div>
          <TrailDivider />
          <section
            className="manifesto-section"
            aria-labelledby="manifesto-title"
          >
            <div className="section-shell manifesto-layout">
              <blockquote className="manifesto-quote">
                <h2 id="manifesto-title">“{copy.quote}”</h2>
              </blockquote>
              <div className="manifesto-copy">
                <p>{copy.motivation}</p>
                <p>{copy.reasons}</p>
                <p>
                  <strong>{copy.closing}</strong>
                  <br />
                  {copy.rhythm}
                </p>
                <a
                  className="button button-secondary fill-link cta-button"
                  href="/get-inspired"
                >
                  Get Inspired
                </a>
              </div>
            </div>
          </section>
          <TrailDivider />
          <section className="paths-section" id="paths">
            <div className="section-shell">
              <h2 className="section-title">Choose Your Path</h2>
              <div className="path-grid home-path-grid">
                {paths.map((path) => (
                  <article className="path-card" key={path.title}>
                    <div className="path-card-link">
                      <div className="path-image-wrap">
                        <Image
                          className="path-image"
                          src={path.image}
                          alt={path.alt}
                          fill
                          sizes="(max-width: 760px) 100vw, 33vw"
                        />
                      </div>
                      <div className="path-card-shade" />
                      <div className="path-card-body">
                        <h3>{path.title}</h3>
                        <p>{path.copy}</p>
                        <a
                          className="button button-secondary fill-link cta-button"
                          href={path.href}
                        >
                          {path.action}
                        </a>
                      </div>
                    </div>
                  </article>
                ))}
              </div>
            </div>
          </section>
          <TrailDivider />
          <section
            className="section-shell foundation-section home-foundation"
            aria-labelledby="foundation-title"
          >
            <h2 className="section-title" id="foundation-title">
              Current Project Focus
            </h2>
            <h3>
              Our Foundation:
              <br />
              The E4 Cyprus Trail
            </h3>
            <p>{copy.focus}</p>
            <a className="button button-secondary" href="/about">
              Read about the Eurotrex Initiative
            </a>
          </section>
          <TrailDivider />
          <AppDownload id="hikers" screenshots />
          <TrailDivider />
          <section
            className="section-shell community-links"
            aria-labelledby="community-links-title"
          >
            <h2 className="section-title" id="community-links-title">
              Get Involved
            </h2>
            <div>
              {involvement.map(([title, text, label, href]) => (
                <article key={title}>
                  <h3>{title}</h3>
                  <p>{text}</p>
                  <a
                    className="button button-secondary fill-link cta-button"
                    href={href}
                  >
                    {label}
                  </a>
                </article>
              ))}
            </div>
          </section>
          <TrailDivider />
          <section className="faq-section" id="faq">
            <div className="section-shell faq-layout">
              <h2 className="section-title">Quick Answers</h2>
              <div className="faq-list">
                <details>
                  <summary>Which trail does Eurotrex currently cover?</summary>
                  <p>
                    We are building our foundations on the E4 Cyprus trail.
                    Explore the guide for route information from our trail
                    database.
                  </p>
                </details>
                <details>
                  <summary>Can I use the app without mobile coverage?</summary>
                  <p>
                    Download route and stage information before setting off.
                    Live updates and external booking pages still need a
                    connection.
                  </p>
                </details>
                <details>
                  <summary>How can I become a host?</summary>
                  <p>
                    Individuals, businesses and organisations can apply. Your
                    account and accommodation listing are reviewed separately.
                  </p>
                  <a
                    className="button button-secondary fill-link cta-button"
                    href="/become-a-host"
                  >
                    Learn about hosting
                  </a>
                </details>
                <details>
                  <summary>When can I join a mapping expedition?</summary>
                  <p>
                    See our expedition schedule and register your interest in
                    walking with us.
                  </p>
                  <a
                    className="button button-secondary fill-link cta-button"
                    href="/get-involved#expeditions"
                  >
                    See Trail Schedule
                  </a>
                </details>
              </div>
            </div>
          </section>
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
