import Image from 'next/image';
import Link from 'next/link';

const appFeatures = [
  ['Offline trail maps', 'Keep the E4 route, stages and elevation profile with you beyond mobile coverage.'],
  ['Smarter stage planning', 'Shape a day-by-day route around your pace, overnight preferences and available time.'],
  ['Practical stays', 'Find affordable trail-side accommodation so you can carry less, camp less and hike farther.'],
];

const paths = [
  {
    label: 'For hikers',
    icon: '01',
    copy: 'Navigate seamlessly with the EuroTrex E4 mobile app. Access trail data, track elevation profiles and find affordable places to stay.',
    action: 'Get the EuroTrex E4 app',
    href: '#download',
  },
  {
    label: 'For hosts',
    icon: '02',
    copy: 'Offer a tired walker a soft mattress, a hot shower and a warm welcome. Help us build a reliable trail-side hospitality network.',
    action: 'Become a verified host',
    href: '/portal',
  },
  {
    label: 'For sponsors',
    icon: '03',
    copy: 'Connect your outdoor brand with European hikers at the moment they need gear, practical advice and replacements.',
    action: 'Become a sponsor',
    href: 'mailto:info@eurotrex.eu?subject=EuroTrex%20sponsorship',
  },
];

const involvement = [
  ['Volunteer', 'Help with regional trail-data collection as the EuroTrex network expands.', 'Apply to volunteer', 'mailto:info@eurotrex.eu?subject=EuroTrex%20volunteer'],
  ['Work with us', 'Ask about operational and collaboration opportunities across Europe.', 'View opportunities', 'mailto:info@eurotrex.eu?subject=Working%20with%20EuroTrex'],
  ['Walk with us', 'Join us on the trail and share the landscapes and stories you find along the way.', 'See the trail schedule', 'mailto:info@eurotrex.eu?subject=Walking%20with%20EuroTrex'],
  ['Support the vision', 'Help us keep European long-distance hiking practical and accessible.', 'Support EuroTrex', 'mailto:info@eurotrex.eu?subject=Supporting%20EuroTrex'],
];

const faqs = [
  ['Do I need to be an experienced hiker?', 'No. EuroTrex is being designed to make long-distance trails approachable for beginners of different ages, with clear route information and practical planning tools.'],
  ['What is the current project focus?', 'We are building our foundation on the E4 Cyprus trail, co-funded by the Republic of Cyprus, before expanding to Greece and other European E-paths.'],
  ['Does the website offer hiker accounts?', 'No. Hikers use the EuroTrex mobile app. Website accounts are reserved for accommodation partners and EuroTrex administrators.'],
  ['Can accommodation owners list a property?', 'Yes. An owner creates a partner account, submits property and trail-location details, and can maintain approved listings from the owner dashboard.'],
];

export default function Home() {
  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStoreUrl = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site';
  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      { '@type': 'Organization', name: 'EuroTrex', url: siteUrl, logo: `${siteUrl}/icon.png`, email: 'info@eurotrex.eu' },
      { '@type': 'MobileApplication', name: 'EuroTrex', operatingSystem: 'iOS, Android', applicationCategory: 'TravelApplication', description: 'Accessible guidance, offline maps, stage planning and accommodation for Europe’s long-distance trails, starting with the Cyprus E4.' },
      { '@type': 'FAQPage', mainEntity: faqs.map(([question, answer]) => ({ '@type': 'Question', name: question, acceptedAnswer: { '@type': 'Answer', text: answer } })) },
    ],
  };

  return (
    <main>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }} />
      <header className="site-header">
        <Link className="brand" href="/" aria-label="EuroTrex home">
          <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} priority />
        </Link>
        <span className="header-route" aria-hidden="true">E4 / CYPRUS / 01</span>
        <nav aria-label="Primary navigation">
          <a href="#paths">Choose your path</a>
          <a href="#project">Our focus</a>
          <a href="#involved">Get involved</a>
          <Link className="owner-link" href="/portal">Host portal</Link>
        </nav>
      </header>

      <section className="hero">
        <Image className="hero-image" src="/cyprus-e4-forest.jpg" alt="The E4 trail through a Cyprus forest" fill priority sizes="100vw" />
        <div className="hero-shade" />
        <div className="hero-content">
          <p className="eyebrow">EUROPE’S LONG-DISTANCE TRAILS / MADE ACCESSIBLE</p>
          <h1>Find your way<br />with EuroTrex.</h1>
          <p className="hero-copy">We simplify everything you need to explore Europe’s long-distance trails—making them accessible to beginners of all ages.</p>
          <div className="hero-actions">
            <a className="button button-primary" href="#paths">Start your journey</a>
            <a className="button button-glass" href="#story">Get inspired</a>
          </div>
        </div>
        <div className="trail-marker" aria-hidden="true"><small>EUROPEAN</small><span>E4</span><b>→</b></div>
        <div className="hero-rail" aria-hidden="true"><span>CYPRUS</span><span>PROJECT 01</span><span>OFFLINE READY</span></div>
      </section>

      <section className="story-section" id="story">
        <p className="eyebrow dark">THE WAY APPEARS AS YOU WALK</p>
        <blockquote>“You don’t need to be the fastest or the strongest to go far.”</blockquote>
        <div className="story-copy">
          <p>What matters is the sense of adventure, the joy of wandering and the curiosity to see what lies beyond the next hill.</p>
          <p className="story-signoff">Start walking. Plan less. Discover more.<br /><strong>Slowly. Deeply. One step at a time.</strong></p>
        </div>
      </section>

      <section className="paths-section" id="paths">
        <div className="section-heading">
          <div><p className="eyebrow dark">CHOOSE YOUR PATH</p><h2>There’s a place for you<br />on the trail.</h2></div>
          <p className="section-intro">Walk it, welcome those who do, or help the network grow.</p>
        </div>
        <div className="path-grid">
          {paths.map((path) => (
            <article className="path-card" key={path.label}>
              <span className="path-icon" aria-hidden="true">{path.icon}</span>
              <p className="eyebrow dark">{path.label.toUpperCase()}</p>
              <h3>{path.label}</h3>
              <p>{path.copy}</p>
              {path.href.startsWith('/') ? <Link href={path.href}>{path.action}<span aria-hidden="true">→</span></Link> : <a href={path.href}>{path.action}<span aria-hidden="true">→</span></a>}
            </article>
          ))}
        </div>
      </section>

      <section className="feature-section" id="explore">
        <div className="section-heading">
          <div><p className="eyebrow dark">FOR HIKERS</p><h2>Everything the next<br />stage needs.</h2></div>
          <p className="section-intro">A clear trail companion that keeps the essentials close without getting between you and the landscape.</p>
        </div>
        <div className="feature-grid">
          {appFeatures.map(([title, copy], index) => (
            <article className="feature-card" key={title}>
              <span className="feature-number">0{index + 1}</span>
              <h3>{title}</h3>
              <p>{copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="project-section" id="project">
        <div className="project-mark" aria-hidden="true"><span>EUROPEAN</span><strong>E4</strong><span>CYPRUS</span></div>
        <div>
          <p className="eyebrow">CURRENT PROJECT FOCUS</p>
          <h2>Our foundation:<br />the E4 Cyprus trail.</h2>
          <p>We are currently building on the E4 Cyprus trail, co-funded by the Republic of Cyprus. As EuroTrex grows, we look forward to expanding our mobile guides and host networks across Greece and the rest of the European E-paths.</p>
          <a className="text-link light" href="#faq">Read about the EuroTrex initiative <span aria-hidden="true">→</span></a>
        </div>
      </section>

      <section className="partner-section" id="partners">
        <div className="partner-intro">
          <p className="eyebrow dark">FOR ACCOMMODATION PARTNERS</p>
          <h2>Put your stay on the hiker’s path.</h2>
          <p>Hosts are an integral part of the trail. Submit your property, follow its review and keep an approved listing accurate from one simple portal.</p>
          <Link className="button button-primary" href="/portal">Open the host portal</Link>
        </div>
        <ol className="partner-steps">
          <li><span>1</span><div><strong>Create a host account</strong><p>Website accounts are only for accommodation partners and administrators.</p></div></li>
          <li><span>2</span><div><strong>Submit trail-ready details</strong><p>Add your nearest stage, location, price range and contact information.</p></div></li>
          <li><span>3</span><div><strong>Get verified and published</strong><p>Approved accommodation becomes available inside the EuroTrex app.</p></div></li>
        </ol>
      </section>

      <section className="involved-section" id="involved">
        <div className="section-heading">
          <div><p className="eyebrow dark">GET INVOLVED</p><h2>Help the path<br />reach farther.</h2></div>
          <p className="section-intro">EuroTrex grows through local knowledge, collaboration and the people who show up for the trail.</p>
        </div>
        <div className="involved-grid">
          {involvement.map(([title, copy, action, href], index) => (
            <article key={title}>
              <span>0{index + 1}</span>
              <h3>{title}</h3>
              <p>{copy}</p>
              <a href={href}>{action} <b aria-hidden="true">↗</b></a>
            </article>
          ))}
        </div>
      </section>

      <section className="download-section" id="download">
        <div>
          <p className="eyebrow">THE E4 IN YOUR POCKET</p>
          <h2>Ready when the trail is.</h2>
          <p>EuroTrex for iPhone and Android is coming soon. Download links will appear here at release.</p>
        </div>
        <div className="store-buttons" aria-label="App downloads">
          {appStoreUrl ? <a href={appStoreUrl} target="_blank" rel="noreferrer"><small>Download on the</small>App Store</a> : <span><small>Coming soon to the</small>App Store</span>}
          {playStoreUrl ? <a href={playStoreUrl} target="_blank" rel="noreferrer"><small>Get it on</small>Google Play</a> : <span><small>Coming soon to</small>Google Play</span>}
        </div>
      </section>

      <section className="faq-section" id="faq">
        <div><p className="eyebrow dark">QUICK ANSWERS</p><h2>Know before<br />you go.</h2></div>
        <div className="faq-list">{faqs.map(([question, answer]) => <details key={question}><summary>{question}</summary><p>{answer}</p></details>)}</div>
      </section>

      <footer className="site-footer">
        <div className="footer-brand"><Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} /><p>Explore Europe’s long-distance trails with clarity.</p><a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a></div>
        <div className="footer-links">
          <div><strong>Explore</strong><a href="#explore">E4 trail app</a><a href="#story">Get inspired</a></div>
          <div><strong>Partner network</strong><Link href="/portal">Become a host</Link><a href="mailto:info@eurotrex.eu?subject=EuroTrex%20sponsorship">Become a sponsor</a></div>
          <div><strong>Community</strong><a href="#involved">Get involved</a><Link href="/privacy">Privacy</Link><Link href="/partner-terms">Partner policy</Link></div>
        </div>
        <div className="funding-logos"><Image src="/eu-cofunded-logo.png" alt="Co-funded by the European Union" width={160} height={55} /><Image src="/republic-of-cyprus.png" alt="Republic of Cyprus" width={160} height={55} /></div>
      </footer>
    </main>
  );
}
