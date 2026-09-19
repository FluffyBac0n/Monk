import Image from 'next/image';
import Link from 'next/link';
import { SITE_URL } from '@/lib/site';
import MobileMenu from './mobile-menu';

const paths = [
  {
    label: 'For hikers',
    image: '/cyprus-e4-forest.jpg',
    alt: 'A marked section of the E4 long-distance trail through a Cyprus forest',
    copy: 'Plan stages, follow the route offline and find practical places to stay with the EuroTrex mobile app.',
    action: 'Explore the hiker app',
    href: '#hikers',
    featured: true,
  },
  {
    label: 'For hosts',
    image: '/hosts-path.webp',
    alt: 'A welcoming stone guesthouse beside a Cyprus hiking route',
    copy: 'Put a warm, affordable stay on the trail and help hikers travel lighter, safer and farther.',
    action: 'Become a verified host',
    href: '/portal',
  },
  {
    label: 'For sponsors',
    image: '/sponsors-path.webp',
    alt: 'A hiker adjusting practical outdoor equipment beside a trail waymark',
    copy: 'Support a more accessible European trail network through useful equipment and responsible partnerships.',
    action: 'Talk to EuroTrex',
    href: 'mailto:info@eurotrex.eu?subject=EuroTrex%20sponsorship',
  },
];

const appFeatures = [
  ['Offline route guidance', 'Carry the Cyprus E4 route, stage details and essential context beyond mobile coverage.'],
  ['Flexible trip planning', 'Choose your start and finish, compare walking days and shape a route around your pace.'],
  ['Elevation at a glance', 'Understand the climbs and descents ahead before you commit to the next stage.'],
  ['Trail-side stays', 'Find practical accommodation close to the route and contact verified hosts.'],
];

const hostSteps = [
  {
    title: 'Create your account',
    copy: 'Register as an accommodation partner and tell us who you represent.',
    image: '/host-step-account-photo.webp',
    alt: 'A Cyprus guesthouse owner creating a host account on a laptop',
  },
  {
    title: 'Add the essentials',
    copy: 'Share your location, nearest stage, price range and reliable contact information.',
    image: '/host-step-details-photo.webp',
    alt: 'A Cyprus guesthouse owner checking trail-ready property details',
  },
  {
    title: 'Submit for verification',
    copy: 'Approved information becomes available to hikers inside the EuroTrex app.',
    image: '/host-step-verified-photo.webp',
    alt: 'A hiker finding a verified trail-side guesthouse',
  },
];

const involvement = [
  { title: 'Volunteer', copy: 'Contribute local knowledge and help verify trail information as the network grows.', action: 'Volunteer with us', href: 'mailto:info@eurotrex.eu?subject=EuroTrex%20volunteer', image: '/involved-volunteer.webp', alt: 'Illustration of a volunteer checking a trail waymark and recording a field note' },
  { title: 'Collaborate', copy: 'Work with EuroTrex on responsible tourism, trail access and regional initiatives.', action: 'Start a conversation', href: 'mailto:info@eurotrex.eu?subject=Working%20with%20EuroTrex', image: '/involved-collaborate.webp', alt: 'Illustration of two collaborators connecting sections of a trail route together' },
  { title: 'Walk with us', copy: 'Join field walks and share the landscapes, conditions and stories you find.', action: 'Ask about field walks', href: 'mailto:info@eurotrex.eu?subject=Walking%20with%20EuroTrex', image: '/involved-walk.webp', alt: 'Illustration of two hikers walking together on a Cyprus trail' },
  { title: 'Support the vision', copy: 'Help keep European long-distance hiking practical, welcoming and accessible.', action: 'Support EuroTrex', href: 'mailto:info@eurotrex.eu?subject=Supporting%20EuroTrex', image: '/involved-support.webp', alt: 'Illustration of people helping a trail network reach a new waypoint' },
];

const faqs = [
  ['Which trail does EuroTrex currently cover?', 'EuroTrex is starting with the E4 long-distance trail in Cyprus. The project is building a reliable digital guide, stage-planning tools and a trail-side host network before expanding to more European E-paths.'],
  ['Can I use the app without mobile coverage?', 'Yes. EuroTrex is designed around offline route guidance so hikers can keep the E4 trail and essential stage information available when reception is limited.'],
  ['Do I need to be an experienced long-distance hiker?', 'No. Clear stages, elevation context, route planning and nearby stays are designed to make the Cyprus E4 more approachable for first-time and experienced hikers alike.'],
  ['When will the iPhone and Android apps be available?', 'The EuroTrex apps for iPhone and Android are in preparation. The official store badges on this page will link directly to each verified listing when the apps are released.'],
  ['Can accommodation owners list a property?', 'Yes. Eligible owners can create a host account, submit property and trail-location details, follow the review and maintain an approved listing through the EuroTrex host portal.'],
];

function ActionLink({ href, children, className = '' }: { href: string; children: React.ReactNode; className?: string }) {
  const classes = `fill-link ${className}`.trim();
  return href.startsWith('/') ? (
    <Link className={classes} href={href}><span>{children}</span></Link>
  ) : (
    <a className={classes} href={href}><span>{children}</span></a>
  );
}

export default function Home() {
  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStoreUrl = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  const storeUrls = [appStoreUrl, playStoreUrl].filter(Boolean);

  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'Organization',
        '@id': `${SITE_URL}/#organization`,
        name: 'EuroTrex',
        url: SITE_URL,
        logo: `${SITE_URL}/eurotrex-app-icon.png`,
        email: 'info@eurotrex.eu',
      },
      {
        '@type': 'WebSite',
        '@id': `${SITE_URL}/#website`,
        url: SITE_URL,
        name: 'EuroTrex',
        publisher: { '@id': `${SITE_URL}/#organization` },
        inLanguage: 'en',
      },
      {
        '@type': 'WebPage',
        '@id': `${SITE_URL}/#webpage`,
        url: SITE_URL,
        name: 'EuroTrex — Cyprus E4 trail app and route planner',
        description: 'Plan and navigate the Cyprus E4 with offline maps, flexible stages, elevation context and practical trail-side stays.',
        isPartOf: { '@id': `${SITE_URL}/#website` },
        about: { '@id': `${SITE_URL}/#app` },
        inLanguage: 'en',
      },
      {
        '@type': 'MobileApplication',
        '@id': `${SITE_URL}/#app`,
        name: 'EuroTrex',
        url: SITE_URL,
        operatingSystem: 'iOS, Android',
        applicationCategory: 'TravelApplication',
        description: 'Offline route guidance, flexible stage planning, elevation context and trail-side accommodation for the Cyprus E4.',
        featureList: appFeatures.map(([feature]) => feature),
        screenshot: [
          `${SITE_URL}/app-stages.webp`,
          `${SITE_URL}/app-planner.webp`,
          `${SITE_URL}/app-elevation.webp`,
        ],
        ...(storeUrls.length ? { sameAs: storeUrls } : {}),
      },
      {
        '@type': 'FAQPage',
        '@id': `${SITE_URL}/#faq`,
        mainEntity: faqs.map(([question, answer]) => ({
          '@type': 'Question',
          name: question,
          acceptedAnswer: { '@type': 'Answer', text: answer },
        })),
      },
    ],
  };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }} />

      <header className="site-header">
        <div className="header-inner">
          <Link className="brand" href="/" aria-label="EuroTrex home">
            <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} priority />
          </Link>
          <span className="route-chip">E4 · Cyprus</span>
          <nav className="desktop-nav" aria-label="Primary navigation">
            <a href="#hikers">For hikers</a>
            <a href="#hosts">For hosts</a>
            <a href="#project">The project</a>
            <a href="#involved">Get involved</a>
            <Link className="nav-portal" href="/portal">Host portal</Link>
          </nav>
          <MobileMenu />
        </div>
      </header>

      <main id="main-content">
        <section className="hero">
          <Image className="hero-image" src="/cyprus-e4-forest.jpg" alt="The E4 long-distance trail through a Cyprus forest" fill priority sizes="100vw" />
          <div className="hero-shade" />
          <div className="hero-inner">
            <div className="hero-content">
              <p className="eyebrow light">The Cyprus E4, made easier</p>
              <h1>Find your way<br />with EuroTrex.</h1>
              <p className="hero-copy">Offline route guidance, flexible stage planning and practical places to stay—one clear companion for exploring Cyprus on foot.</p>
              <div className="hero-actions">
                <ActionLink href="#hikers" className="button button-yellow">Explore the hiker app</ActionLink>
                <ActionLink href="#paths" className="button button-outline">Choose your path</ActionLink>
              </div>
            </div>
            <div className="hero-route" aria-label="Current route: Cyprus E4">
              <span>Current route</span>
              <strong>E4</strong>
              <span>Cyprus</span>
            </div>
          </div>
        </section>

        <section className="manifesto-section" aria-labelledby="manifesto-title">
          <div className="section-shell manifesto-layout">
            <blockquote className="manifesto-quote">
              <p className="eyebrow">The EuroTrex manifesto</p>
              <h2 id="manifesto-title">“When you start to walk on the way, the way appears.”</h2>
            </blockquote>
            <div className="manifesto-copy">
              <p>You don’t need to be an expert, the fastest, or the strongest to go far.</p>
              <p>Because what truly matters is the sense of adventure, the joy of wandering, the curiosity to see what lies beyond the next hill, and the need to reconnect with nature.</p>
              <p className="manifesto-signoff"><strong>Start walking. Plan less. Discover more.</strong><span>Slowly. Deeply. One step at a time.</span></p>
            </div>
          </div>
        </section>

        <section className="paths-section" id="paths" aria-labelledby="paths-title">
          <div className="section-shell">
            <div className="section-heading">
              <div>
                <p className="eyebrow">Choose your path</p>
                <h2 id="paths-title">A trail network shaped by everyone around it.</h2>
              </div>
              <p>Walk it, welcome those who do, or help make the route more useful.</p>
            </div>
            <div className="path-grid">
              {paths.map((path) => (
                <article className={`path-card${path.featured ? ' path-card-featured' : ''}`} key={path.label}>
                  <div className="path-image-wrap">
                    <Image className="path-image" src={path.image} alt={path.alt} fill sizes="(max-width: 760px) 100vw, 33vw" />
                    {path.featured && <span className="featured-label">Start here</span>}
                  </div>
                  <div className="path-card-body">
                    <p className="eyebrow">{path.label}</p>
                    <h3>{path.label}</h3>
                    <p>{path.copy}</p>
                    <ActionLink href={path.href} className="card-link">{path.action}<b aria-hidden="true">→</b></ActionLink>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="hiker-showcase" id="hikers" aria-labelledby="hikers-title">
          <div className="section-shell hiker-layout">
            <div className="hiker-copy reveal">
              <p className="eyebrow light">For hikers</p>
              <h2 id="hikers-title">The Cyprus E4, from first stage to final step.</h2>
              <p className="hiker-intro">The EuroTrex app keeps the decisions that matter close at hand while leaving the landscape centre stage.</p>
              <ul className="feature-list">
                {appFeatures.map(([title, copy]) => (
                  <li key={title}>
                    <span aria-hidden="true">✓</span>
                    <div><strong>{title}</strong><p>{copy}</p></div>
                  </li>
                ))}
              </ul>
              <ActionLink href="#download" className="button button-yellow">See app availability</ActionLink>
            </div>
            <div className="app-gallery reveal" aria-label="Screenshots from the EuroTrex iPhone app">
              <figure className="phone-shot phone-stages">
                <Image src="/app-stages.webp" alt="EuroTrex iPhone app showing Cyprus E4 stages" width={720} height={1565} sizes="(max-width: 760px) 42vw, 230px" />
                <figcaption>Browse stages</figcaption>
              </figure>
              <figure className="phone-shot phone-planner">
                <Image src="/app-planner.webp" alt="EuroTrex iPhone route planner showing the Cyprus E4 on a map" width={720} height={1565} sizes="(max-width: 760px) 46vw, 250px" />
                <figcaption>Shape your trip</figcaption>
              </figure>
              <figure className="phone-shot phone-elevation">
                <Image src="/app-elevation.webp" alt="EuroTrex iPhone app showing an E4 elevation profile" width={720} height={1565} sizes="(max-width: 760px) 42vw, 230px" />
                <figcaption>Read the terrain</figcaption>
              </figure>
            </div>
          </div>
        </section>

        <section className="project-section" id="project" aria-labelledby="project-title">
          <div className="section-shell project-layout">
            <div className="project-badge" aria-hidden="true"><small>European</small><strong>E4</strong><small>Cyprus</small></div>
            <div>
              <p className="eyebrow light">Current project</p>
              <h2 id="project-title">Building from the Cyprus E4 outward.</h2>
              <p>The first EuroTrex guide is focused on the E4 in Cyprus: a long-distance route crossing forests, mountain villages and the island’s changing landscapes. From this foundation, the platform can grow across Greece and other European E-paths.</p>
              <a className="simple-link" href="#faq">Read the quick answers <span aria-hidden="true">→</span></a>
            </div>
            <dl className="project-facts">
              <div><dt>First route</dt><dd>Cyprus E4</dd></div>
              <div><dt>Built for</dt><dd>iOS + Android</dd></div>
              <div><dt>Next</dt><dd>European E-paths</dd></div>
            </dl>
          </div>
        </section>

        <section className="host-section" id="hosts" aria-labelledby="hosts-title">
          <div className="section-shell">
            <div className="host-heading">
              <div>
                <p className="eyebrow">For accommodation hosts</p>
                <h2 id="hosts-title">Your stay on the trail in three simple steps.</h2>
              </div>
              <div className="host-summary">
                <p>No complicated setup. Create an account, add the details hikers need and send your stay for verification. We’ll guide you through each step.</p>
              </div>
            </div>
            <ol className="host-steps" role="list">
              {hostSteps.map((step) => (
                <li key={step.title}>
                  <div className="host-step-image"><Image src={step.image} alt={step.alt} fill sizes="(max-width: 500px) 100vw, (max-width: 760px) 38vw, 33vw" /></div>
                  <div className="host-step-body"><h3>{step.title}</h3><p>{step.copy}</p></div>
                </li>
              ))}
            </ol>
            <div className="host-cta-row">
              <p><strong>Ready to welcome hikers?</strong><span>Start your listing and take it one step at a time.</span></p>
              <ActionLink href="/portal" className="button button-blue">Open the host portal</ActionLink>
            </div>
          </div>
        </section>

        <section className="involved-section" id="involved" aria-labelledby="involved-title">
          <div className="section-shell">
            <div className="section-heading">
              <div><p className="eyebrow">Get involved</p><h2 id="involved-title">Help the path reach farther.</h2></div>
              <p>EuroTrex grows through local knowledge, useful partnerships and people who care for the trail.</p>
            </div>
            <div className="involved-grid">
              {involvement.map(({ title, copy, action, href, image, alt }) => (
                <article key={title}>
                  <div className="involved-image"><Image src={image} alt={alt} fill sizes="(max-width: 500px) 100vw, (max-width: 760px) 42vw, 21vw" /></div>
                  <div className="involved-card-body">
                    <h3>{title}</h3>
                    <p>{copy}</p>
                    <ActionLink href={href} className="card-link">{action}<b aria-hidden="true">↗</b></ActionLink>
                  </div>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className="download-section" id="download" aria-labelledby="download-title">
          <div className="section-shell download-layout">
            <div className="download-copy">
              <Image className="app-icon" src="/eurotrex-app-icon.png" alt="EuroTrex app icon" width={1024} height={1024} />
              <div><p className="eyebrow light">The E4 in your pocket</p><h2 id="download-title">Ready when the trail is.</h2><p>EuroTrex for iPhone and Android is coming soon. The official store links will activate here at release.</p></div>
            </div>
            <div className="store-group" aria-label="EuroTrex app stores">
              <div className="store-item">
                {appStoreUrl ? (
                  <a href={appStoreUrl} target="_blank" rel="noreferrer" aria-label="Download EuroTrex on the App Store">
                    <Image src="/app-store-badge.svg" alt="Download on the App Store" width={180} height={60} />
                  </a>
                ) : (
                  <span className="store-badge" role="img" aria-label="EuroTrex for iPhone — coming soon"><Image src="/app-store-badge.svg" alt="" aria-hidden="true" width={180} height={60} /></span>
                )}
                {!appStoreUrl && <small>Coming soon</small>}
              </div>
              <div className="store-item store-item-google">
                {playStoreUrl ? (
                  <a href={playStoreUrl} target="_blank" rel="noreferrer" aria-label="Get EuroTrex on Google Play">
                    <Image src="/google-play-badge.png" alt="Get it on Google Play" width={194} height={75} />
                  </a>
                ) : (
                  <span className="store-badge" role="img" aria-label="EuroTrex for Android — coming soon"><Image src="/google-play-badge.png" alt="" aria-hidden="true" width={194} height={75} /></span>
                )}
                {!playStoreUrl && <small>Coming soon</small>}
              </div>
            </div>
          </div>
        </section>

        <section className="faq-section section-shell" id="faq" aria-labelledby="faq-title">
          <div><p className="eyebrow">Quick answers</p><h2 id="faq-title">Know before you go.</h2></div>
          <div className="faq-list">
            {faqs.map(([question, answer]) => <details key={question}><summary>{question}</summary><p>{answer}</p></details>)}
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="section-shell footer-main">
          <div className="footer-brand">
            <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} />
            <p>Clearer routes. Lighter planning. More time on the trail.</p>
            <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>
          </div>
          <nav className="footer-nav" aria-label="Footer navigation">
            <div><strong>Explore</strong><a href="#hikers">Hiker app</a><a href="#project">Cyprus E4 project</a><a href="#faq">Questions</a></div>
            <div><strong>Partners</strong><Link href="/portal">Host portal</Link><a href="mailto:info@eurotrex.eu?subject=EuroTrex%20sponsorship">Sponsors</a><a href="#involved">Get involved</a></div>
            <div><strong>Information</strong><Link href="/privacy">Privacy</Link><Link href="/partner-terms">Partner policy</Link></div>
          </nav>
        </div>
        <div className="section-shell funding-row">
          <p className="footer-legal">© {new Date().getFullYear()} EuroTrex. Apple and the Apple logo are trademarks of Apple Inc. Google Play and the Google Play logo are trademarks of Google LLC.</p>
          <div className="funding-marks" aria-label="Project funders">
            <div className="funding-mark">
              <Image src="/eu-flag-color.png" alt="European Union flag" width={1247} height={853} />
              <span>Co-funded by the<br /><strong>European Union</strong></span>
            </div>
            <div className="funding-mark">
              <Image src="/republic-of-cyprus-emblem.png" alt="Republic of Cyprus emblem" width={817} height={812} />
              <span>Co-funded by the<br /><strong>Republic of Cyprus</strong></span>
            </div>
          </div>
        </div>
      </footer>
    </>
  );
}
