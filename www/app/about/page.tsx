import type { Metadata } from 'next';
import Image from 'next/image';
import { InformationPage } from '@/components/InformationPage';

export const metadata: Metadata = { title: 'About Us', description: 'One project connecting trail information, trip planning and accommodation, starting with Cyprus-E4.', alternates: { canonical: '/about' } };

export default function About() {
  return <InformationPage label="About Us" title="More confidence. More time outside." introduction="EuroTrex brings long-distance trails, maps, elevation and practical information together—starting with Cyprus-E4.">
    <figure className="about-landscape"><Image src="/zapalo-coast-hero-1280.webp" alt="Limestone cliffs and Mediterranean water at Zapalo Bay, Cyprus" width={1280} height={853} /><figcaption>Zapalo Bay, Cyprus · The landscape behind the project</figcaption></figure>
    <section><h2>One project, three connected experiences.</h2><dl className="guide-planning-list"><div><dt>The website</dt><dd>Discover trails and read practical information before choosing your walk.</dd></div><div><dt>The mobile app</dt><dd>Plan walking days and carry downloaded route information. The app is currently in private testing.</dd></div><div><dt>The Host Portal</dt><dd>Accommodation representatives maintain listings that can appear in the app after review. Hikers book with hosts directly.</dd></div></dl></section>
    <section><p className="eyebrow">The company and team</p><h2>Built by EuroTrex Ltd.</h2><p>Behind EuroTrex are Pavlos Christofides and Andreas Michaelides.</p></section>
    <section><h2>Information with its limits made clear.</h2><p>We distinguish recorded route data from recent field checks. Published update dates refer to the dataset; they do not guarantee current water, transport or accommodation availability. A host review checks authority, contact details and trail relevance, not the quality of every guest experience.</p><a className="simple-link" href="/help">How to use EuroTrex and report corrections</a></section>
    <section><h2>Help shape what comes next.</h2><p>Local knowledge, field observations and accommodation partners help improve the guide. Crete-E4 and Peloponnese-E4 are planned guides; neither has a confirmed release date.</p><a className="button button-primary" href="/get-involved">Join us</a><p>Contact the EuroTrex team at <a className="simple-link" href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>.</p></section>
  </InformationPage>;
}
