import Image from 'next/image';
import { NotifyButton } from '@/components/NotifyDialog';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicContent } from '@/components/PublicContent';
import { cyprusE4 } from '@/lib/cyprus-e4-data';
import { disableHtmxNavigation, publicHtmxNavigation } from '@/lib/htmx';
import { SITE_URL } from '@/lib/site';

const paths = [
  {
    label: 'For hikers', title: 'Plan the trail', image: '/cyprus-e4-forest.jpg',
    alt: 'A marked section of the E4 long-distance trail through a Cyprus forest',
    copy: 'Plan stages, carry the route offline and find practical places to stay with the EuroTrex mobile app.',
    action: 'Explore the hiker app', href: '#hikers',
  },
  {
    label: 'For hosts', title: 'Welcome hikers', image: '/hosts-path.webp',
    alt: 'A welcoming stone guesthouse beside a Cyprus hiking route',
    copy: 'Put a warm, practical stay on the trail and help hikers travel lighter, safer and farther.',
    action: 'See how listings work', href: '#hosts',
  },
  {
    label: 'For sponsors', title: 'Support the route', image: '/sponsors-path.webp',
    alt: 'A hiker adjusting practical outdoor equipment beside a trail waymark',
    copy: 'Support a more accessible European trail network through useful equipment and responsible partnerships.',
    action: 'Explore partnerships', href: '/partnerships',
  },
];

const appFeatures = [
  ['Offline route guidance', 'Download trail geometry and stage context before leaving mobile coverage.'],
  ['Flexible trip planning', 'Choose your start and finish, compare walking days and shape a route around your pace.'],
  ['Elevation at a glance', 'Understand climbs, descents and the terrain ahead before committing to the next section.'],
  ['Trail-side stays', 'Find practical accommodation near a stage and contact hosts directly.'],
];

const hostSteps = [
  { title: 'Create your account', copy: 'Register as an accommodation partner and tell us who you represent.', image: '/host-step-account-photo.webp', alt: 'A Cyprus guesthouse owner creating a host account on a laptop' },
  { title: 'Add the essentials', copy: 'Share your location, nearest stage, price range and reliable contact information.', image: '/host-step-details-photo.webp', alt: 'A Cyprus guesthouse owner checking trail-ready property details' },
  { title: 'Submit for verification', copy: 'We review owner authority, contact details and trail relevance before publication.', image: '/host-step-verified-photo.webp', alt: 'A hiker finding a verified trail-side guesthouse' },
];

const involvement = [
  { title: 'Volunteer', copy: 'Contribute local knowledge and help check trail information as the network grows.', action: 'Volunteer with us', href: '/get-involved?interest=volunteer', image: '/involved-volunteer.webp', alt: 'Illustration of a volunteer checking a trail waymark and recording a field note' },
  { title: 'Collaborate', copy: 'Work with EuroTrex on responsible tourism, trail access and regional initiatives.', action: 'Start a collaboration', href: '/get-involved?interest=collaborate', image: '/involved-collaborate.webp', alt: 'Illustration of two collaborators connecting sections of a trail route together' },
  { title: 'Walk with us', copy: 'Join field walks and share the conditions and stories you find along the route.', action: 'Ask about field walks', href: '/get-involved?interest=field-walks', image: '/involved-walk.webp', alt: 'Illustration of two hikers walking together on a Cyprus trail' },
  { title: 'Support the vision', copy: 'Help keep long-distance hiking practical, welcoming and accessible.', action: 'Explore partnerships', href: '/partnerships', image: '/involved-support.webp', alt: 'Illustration of people helping a trail network reach a new waypoint' },
];

const faqs = [
  ['Which trail does EuroTrex currently cover?', 'EuroTrex is starting with the 558 km Cyprus E4, from Pafos Airport to Larnaka Airport. The current dataset includes 123 named stage points.'],
  ['Can I use the app without mobile coverage?', 'Yes. EuroTrex is designed around downloaded route geometry and stage information, so essential trail context remains available when reception is limited.'],
  ['Do I need to be an experienced long-distance hiker?', 'No. Flexible planning, elevation context and nearby stays are designed to make the trail more approachable for both first-time and experienced long-distance hikers.'],
  ['When will the iPhone and Android apps be available?', 'The iPhone and Android apps are in preparation. Ask to be notified and EuroTrex will email you when testing invitations or verified store links are ready.'],
  ['What does a verified accommodation mean?', 'EuroTrex reviews the owner’s authority, contact details and relevance to the trail. Verification is not an endorsement or a booking guarantee; hikers still book directly with each host.'],
];

function ActionLink({ href, children, className = '' }: { href: string; children: React.ReactNode; className?: string }) {
  const classes = `fill-link ${className}`.trim();
  const navigation = href.startsWith('/portal') ? disableHtmxNavigation : {};
  return <a className={classes} href={href} {...navigation}><span>{children}</span></a>;
}

function TrailDivider() {
  return <div className="trail-divider" aria-hidden="true" />;
}

export default function Home() {
  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStoreUrl = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  const storeUrls = [appStoreUrl, playStoreUrl].filter(Boolean);
  const updated = new Intl.DateTimeFormat('en-GB', { dateStyle: 'long', timeZone: 'UTC' }).format(new Date(cyprusE4.dataUpdatedAt));

  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      { '@type': 'Organization', '@id': `${SITE_URL}/#organization`, name: 'EuroTrex', url: SITE_URL, logo: `${SITE_URL}/eurotrex-app-icon.png`, email: 'info@eurotrex.eu' },
      { '@type': 'WebSite', '@id': `${SITE_URL}/#website`, url: SITE_URL, name: 'EuroTrex', publisher: { '@id': `${SITE_URL}/#organization` }, inLanguage: 'en' },
      { '@type': 'WebPage', '@id': `${SITE_URL}/#webpage`, url: SITE_URL, name: 'EuroTrex — Cyprus E4 trail app and route planner', description: 'Plan and navigate the Cyprus E4 with offline maps, flexible stages, elevation context and practical trail-side stays.', isPartOf: { '@id': `${SITE_URL}/#website` }, about: { '@id': `${SITE_URL}/#app` }, inLanguage: 'en' },
      { '@type': 'MobileApplication', '@id': `${SITE_URL}/#app`, name: 'EuroTrex', url: SITE_URL, operatingSystem: 'iOS, Android', applicationCategory: 'TravelApplication', description: 'Offline route guidance, flexible stage planning, elevation context and trail-side accommodation for the Cyprus E4.', featureList: appFeatures.map(([feature]) => feature), screenshot: [`${SITE_URL}/app-stages.webp`, `${SITE_URL}/app-planner.webp`, `${SITE_URL}/app-elevation.webp`], ...(storeUrls.length ? { sameAs: storeUrls } : {}) },
      { '@type': 'FAQPage', '@id': `${SITE_URL}/#faq`, mainEntity: faqs.map(([question, answer]) => ({ '@type': 'Question', name: question, acceptedAnswer: { '@type': 'Answer', text: answer } })) },
    ],
  };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <PublicHeader />

      <PublicContent>
      <main id="main-content" tabIndex={-1} {...publicHtmxNavigation}>
        <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }} />
        <section className="hero">
          <div className="hero-media">
            <Image className="hero-image" src="/cyprus-e4-forest.jpg" alt="The E4 long-distance trail through a Cyprus forest" fill priority sizes="(max-width: 760px) 100vw, 78vw" />
          </div>
          <div className="hero-shade" />
          <div className="hero-inner">
            <div className="hero-content">
              <h1>Find your way<br />with EuroTrex.</h1>
              <p className="hero-copy">We simplify everything you need to explore Europe’s long-distance trails—making them accessible to beginners of all ages.</p>
              <div className="hero-actions">
                <ActionLink href="/trails/cyprus-e4" className="button button-outline">Explore the Cyprus E4</ActionLink>
              </div>
            </div>
          </div>
        </section>

        <section className="manifesto-section" aria-labelledby="manifesto-title">
          <div className="section-shell manifesto-layout">
            <blockquote className="manifesto-quote"><p className="eyebrow">The EuroTrex manifesto</p><h2 id="manifesto-title">“When you start to walk on the way, the way appears.”</h2></blockquote>
            <div className="manifesto-copy"><p>You don’t need to be an expert, the fastest, or the strongest to go far.</p><p>What matters is the sense of adventure, the joy of wandering, the curiosity to see what lies beyond the next hill, and the need to reconnect with nature.</p><p className="manifesto-signoff"><strong>Start walking. Plan less. Discover more.</strong><span>Slowly. Deeply. One step at a time.</span></p></div>
          </div>
        </section>

        <TrailDivider />

        <section className="paths-section" id="paths" aria-labelledby="paths-title">
          <div className="section-shell">
            <div className="section-heading"><div><p className="eyebrow">Choose your path</p><h2 id="paths-title">A trail network shaped by everyone around it.</h2></div><p>Walk it, welcome those who do, or help make the route more useful.</p></div>
            <div className="path-grid">
              {paths.map((path) => (
                <article className="path-card" key={path.label}>
                  <a className="path-card-link" href={path.href}>
                    <div className="path-image-wrap"><Image className="path-image" src={path.image} alt={path.alt} fill sizes="(max-width: 760px) 42vw, 33vw" /></div>
                    <div className="path-card-body"><p className="eyebrow">{path.label}</p><h3>{path.title}</h3><p>{path.copy}</p><span className="card-link">{path.action}<b aria-hidden="true">→</b></span></div>
                  </a>
                </article>
              ))}
            </div>
          </div>
        </section>

        <TrailDivider />

        <section className="hiker-showcase" id="hikers" aria-labelledby="hikers-title">
          <div className="section-shell hiker-layout">
            <div className="hiker-heading reveal">
              <p className="eyebrow">For hikers</p>
              <h2 id="hikers-title">Plan the trail. Keep the adventure.</h2>
              <p className="hiker-intro">EuroTrex keeps the decisions that matter close at hand while leaving the landscape centre stage.</p>
            </div>
            <div className="app-gallery-wrap reveal">
              <div className="app-gallery" aria-label="Screenshots from the EuroTrex iPhone app" role="region" tabIndex={0}>
                <figure className="phone-shot phone-planner"><Image src="/app-planner.webp" alt="EuroTrex iPhone route planner showing the Cyprus E4 on a map" width={720} height={1565} sizes="(max-width: 760px) 72vw, 250px" /><figcaption>Shape your trip</figcaption></figure>
                <figure className="phone-shot phone-stages"><Image src="/app-stages.webp" alt="EuroTrex iPhone app showing Cyprus E4 stages" width={720} height={1565} sizes="(max-width: 760px) 72vw, 230px" /><figcaption>Browse stage points</figcaption></figure>
                <figure className="phone-shot phone-elevation"><Image src="/app-elevation.webp" alt="EuroTrex iPhone app showing an E4 elevation profile" width={720} height={1565} sizes="(max-width: 760px) 72vw, 230px" /><figcaption>Read the terrain</figcaption></figure>
              </div>
              <p className="swipe-hint">Swipe to explore the app <span aria-hidden="true">→</span></p>
            </div>
            <div className="hiker-features reveal">
              <ul className="feature-list">
                {appFeatures.map(([title, copy]) => <li key={title}><span aria-hidden="true">✓</span><div><strong>{title}</strong><p>{copy}</p></div></li>)}
              </ul>
            </div>
            <div className="hiker-launch-band" id="app-updates" aria-labelledby="download-title">
              <Image className="app-icon" src="/eurotrex-app-icon.png" alt="EuroTrex app icon" width={1024} height={1024} />
              <div className="hiker-launch-copy"><p className="eyebrow">The E4 in your pocket</p><h3 id="download-title">Be first on the trail.</h3><p>Get testing invitations and verified iPhone or Android store links when they are ready.</p></div>
              <div className="hiker-launch-actions" aria-label="EuroTrex app availability" role="group">
                <div className="store-item">{appStoreUrl ? <a href={appStoreUrl} target="_blank" rel="noreferrer" aria-label="Download EuroTrex on the App Store"><Image src="/app-store-badge.svg" alt="Download on the App Store" width={180} height={60} /></a> : <span className="store-badge"><Image src="/app-store-badge.svg" alt="" aria-hidden="true" width={180} height={60} /></span>}</div>
                <div className="store-item store-item-google">{playStoreUrl ? <a href={playStoreUrl} target="_blank" rel="noreferrer" aria-label="Get EuroTrex on Google Play"><Image src="/google-play-badge.png" alt="Get it on Google Play" width={194} height={75} /></a> : <span className="store-badge"><Image src="/google-play-badge.png" alt="" aria-hidden="true" width={194} height={75} /></span>}</div>
                <NotifyButton className="button button-yellow">Notify me</NotifyButton>
              </div>
            </div>
          </div>
        </section>

        <TrailDivider />

        <section className="project-section" id="project" aria-labelledby="project-title">
          <div className="section-shell project-layout">
            <div className="project-copy">
              <div className="project-kicker"><div className="project-badge" aria-hidden="true"><small>European</small><strong>E4</strong><small>Cyprus</small></div><p className="eyebrow">Current trail</p></div>
              <h2 id="project-title">From Pafos to Larnaka, one stage point at a time.</h2><p>The first EuroTrex guide follows the Cyprus E4 across coast, forest and the Troodos mountains. Public stage pages expose practical facts now; the app adds flexible planning and offline navigation.</p><a className="simple-link" href="/trails/cyprus-e4">Open the Cyprus E4 guide <span aria-hidden="true">→</span></a>
            </div>
            <dl className="project-facts"><div><dt>Distance</dt><dd>{cyprusE4.distanceKm.toFixed(1)} km</dd></div><div><dt>Stage points</dt><dd>{cyprusE4.stageCount}</dd></div><div><dt>High point</dt><dd>{Math.round(cyprusE4.highPointM).toLocaleString('en-GB')} m</dd></div><div><dt>Trail data updated</dt><dd>{updated}</dd></div></dl>
          </div>
        </section>

        <TrailDivider />

        <section className="host-section" id="hosts" aria-labelledby="hosts-title">
          <div className="section-shell">
            <div className="host-heading"><div><p className="eyebrow">For accommodation hosts</p><h2 id="hosts-title">A clear, three-step path to the trail.</h2></div><div className="host-summary"><p>Hotels, guesthouses, hostels, apartments, villas and camping providers can submit a stay. Hikers contact and book with hosts directly.</p></div></div>
            <ol className="host-steps" role="list">
              {hostSteps.map((step) => <li key={step.title}><div className="host-step-image"><Image src={step.image} alt={step.alt} fill sizes="(max-width: 500px) 38vw, (max-width: 900px) 38vw, 33vw" /></div><div className="host-step-body"><h3>{step.title}</h3><p>{step.copy}</p></div></li>)}
            </ol>
            <dl className="host-facts">
              <div><dt>Eligibility</dt><dd>Authorised accommodation representatives near a named trail stage.</dd></div>
              <div><dt>Booking model</dt><dd>Direct with the host; EuroTrex does not process guest payments.</dd></div>
              <div><dt>Pilot terms</dt><dd>Any fee or commission terms are confirmed before publication.</dd></div>
              <div><dt>Review timing</dt><dd>Manual during private testing; status appears in your portal.</dd></div>
            </dl>
            <div className="host-cta-row"><p><strong>Ready to welcome hikers?</strong><span>Start a guided draft or manage an existing listing.</span></p><ActionLink href="/portal" className="host-portal-link">Open the host portal</ActionLink></div>
          </div>
        </section>

        <TrailDivider />

        <section className="involved-section" id="involved" aria-labelledby="involved-title">
          <div className="section-shell">
            <div className="section-heading"><div><p className="eyebrow">Get involved</p><h2 id="involved-title">Help the path reach farther.</h2></div><p>EuroTrex grows through local knowledge, useful partnerships and people who care for the trail.</p></div>
            <div className="involved-grid">
              {involvement.map(({ title, copy, action, href, image, alt }) => (
                <article key={title}><a className="involved-card-link" href={href}><div className="involved-image"><Image src={image} alt={alt} fill sizes="(max-width: 820px) 36vw, 21vw" /></div><div className="involved-card-body"><h3>{title}</h3><p>{copy}</p><span className="card-link">{action}<b aria-hidden="true">→</b></span></div></a></article>
              ))}
            </div>
          </div>
        </section>

        <TrailDivider />

        <section className="faq-section" id="faq" aria-labelledby="faq-title">
          <div className="section-shell faq-layout"><div><p className="eyebrow">Quick answers</p><h2 id="faq-title">Know before you go.</h2></div><div className="faq-list">{faqs.map(([question, answer]) => <details key={question}><summary>{question}</summary><p>{answer}</p></details>)}</div></div>
        </section>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
