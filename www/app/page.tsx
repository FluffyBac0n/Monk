import Image from 'next/image';
import Link from 'next/link';

const features = [
  ['Offline trail maps', 'Keep the E4 route, stages and elevation profile with you beyond mobile coverage.'],
  ['Smarter stage planning', 'Shape a day-by-day route around your pace, overnight preferences and available time.'],
  ['Practical stays', 'Discover trail-side accommodation and the services you need before each walking day.'],
];

const faqs = [
  ['What is EuroTrex?', 'EuroTrex is a trail companion for the E4 in Cyprus, bringing route guidance, elevation, tailored stage planning and trail-side accommodation into one mobile app.'],
  ['Does the website offer hiker accounts?', 'No. Hikers use the EuroTrex mobile app. Website accounts are reserved for accommodation partners and EuroTrex administrators.'],
  ['Can accommodation owners list a property?', 'Yes. An owner creates a partner account, submits property and trail-location details, and can maintain approved listings from the owner dashboard.'],
  ['How are accommodations published?', 'The EuroTrex team verifies each submission before publishing it to the relevant trail in the app. Material owner updates are reviewed again before going live.'],
];

export default function Home() {
  const appStoreUrl = process.env.NEXT_PUBLIC_APP_STORE_URL;
  const playStoreUrl = process.env.NEXT_PUBLIC_PLAY_STORE_URL;
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site';
  const structuredData = {
    '@context': 'https://schema.org',
    '@graph': [
      { '@type': 'Organization', name: 'EuroTrex', url: siteUrl, logo: `${siteUrl}/icon.png` },
      { '@type': 'MobileApplication', name: 'EuroTrex', operatingSystem: 'iOS, Android', applicationCategory: 'TravelApplication', description: 'Offline maps, stage planning and accommodation for the Cyprus E4 trail.' },
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
        <nav aria-label="Primary navigation">
          <a href="#explore">Explore</a>
          <a href="#download">Get the app</a>
          <Link className="owner-link" href="/portal">List your stay</Link>
        </nav>
      </header>

      <section className="hero">
        <Image className="hero-image" src="/cyprus-e4-forest.jpg" alt="The E4 trail through a Cyprus forest" fill priority sizes="100vw" />
        <div className="hero-shade" />
        <div className="hero-content">
          <p className="eyebrow">CYPRUS · LONG DISTANCE TRAIL</p>
          <h1>Walk farther.<br />Plan with confidence.</h1>
          <p className="hero-copy">EuroTrex brings the Cyprus E4 route, stages, elevation and trusted places to stay into one trail companion.</p>
          <div className="hero-actions">
            <a className="button button-primary" href="#download">Get EuroTrex</a>
            <Link className="button button-glass" href="/portal">Accommodation partners</Link>
          </div>
        </div>
        <div className="trail-marker" aria-hidden="true"><span>E4</span><b>→</b></div>
      </section>

      <section className="partner-section" id="partners">
        <div className="partner-intro">
          <p className="eyebrow dark">FOR ACCOMMODATION PARTNERS</p>
          <h2>Put your stay on the hiker’s path.</h2>
          <p>Owners can submit a property, track its review and keep an approved listing accurate. Every listing is checked by EuroTrex before it reaches hikers.</p>
          <Link className="button button-primary" href="/portal">Open the owner portal</Link>
        </div>
        <ol className="partner-steps">
          <li><span>1</span><div><strong>Create an owner account</strong><p>Website accounts are only for accommodation partners and administrators.</p></div></li>
          <li><span>2</span><div><strong>Submit trail-ready details</strong><p>Add your nearest stage, location, price range and contact information.</p></div></li>
          <li><span>3</span><div><strong>Get verified and published</strong><p>Approved accommodation becomes available inside the EuroTrex app.</p></div></li>
        </ol>
      </section>

      <section className="feature-section" id="explore">
        <div className="section-heading">
          <div><p className="eyebrow dark">YOUR TRAIL, MADE CLEAR</p><h2>Everything the next stage needs.</h2></div>
        </div>
        <div className="feature-grid">
          {features.map(([title, copy], index) => (
            <article className="feature-card" key={title}>
              <span className="feature-number">0{index + 1}</span>
              <h3>{title}</h3>
              <p>{copy}</p>
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
        <div><p className="eyebrow dark">QUICK ANSWERS</p><h2>Know before you go.</h2></div>
        <div className="faq-list">{faqs.map(([question, answer]) => <details key={question}><summary>{question}</summary><p>{answer}</p></details>)}</div>
      </section>

      <footer className="site-footer">
        <div><Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} /><p>Explore Europe’s long-distance trails with clarity.</p></div>
        <div className="funding-logos"><Image src="/eu-cofunded-logo.png" alt="Co-funded by the European Union" width={160} height={55} /><Image src="/republic-of-cyprus.png" alt="Republic of Cyprus" width={160} height={55} /></div>
        <nav aria-label="Footer"><Link href="/portal">Partner portal</Link><Link href="/partner-terms">Partner policy</Link><Link href="/privacy">Privacy</Link></nav>
      </footer>
    </main>
  );
}
