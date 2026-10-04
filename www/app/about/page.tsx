import type { Metadata } from 'next';
import Image from 'next/image';
import { InformationPage } from '@/components/InformationPage';

export const metadata: Metadata = { title: 'About Us', description: 'One project connecting trail information, trip planning and accommodation, starting with Cyprus-E4.', alternates: { canonical: '/about' } };

export default function About() {
  return <InformationPage title="THE TEAM" titleClassName="section-title">
    <section className="team-grid" aria-label="The EuroTrex team">
      {[{ name: 'Petros Christofides', photo: '/team-petros-christofides.webp', alt: 'Petros Christofides overlooking the Cyprus coastline' }, { name: 'Andreas Michaelides', photo: '/team-andreas-michaelides.webp', alt: 'Andreas Michaelides with his dog on a coastal walk in Cyprus' }].map(({ name, photo, alt }) => (
        <article className="team-member" key={name}>
          <Image className="team-photo" src={photo} alt={alt} width={960} height={720} sizes="(max-width: 760px) calc(100vw - 40px), 444px" />
          <h2>{name}</h2>
          <p>Biography to follow.</p>
        </article>
      ))}
    </section>
    <section><h2>More confidence. More time outside.</h2><p>EuroTrex brings long-distance trails, maps, elevation and practical information together—starting with Cyprus-E4.</p></section>
    <figure className="about-landscape"><Image src="/zapalo-coast-hero-1280.webp" alt="Limestone cliffs and Mediterranean water at Zapalo Bay, Cyprus" width={1280} height={853} /><figcaption>Zapalo Bay, Cyprus · The landscape behind the project</figcaption></figure>
    <section><h2>One project, three connected experiences.</h2><dl className="guide-planning-list"><div><dt>The website</dt><dd>Discover trails and read practical information before choosing your walk.</dd></div><div><dt>The mobile app</dt><dd>Plan walking days and carry downloaded route information. The app is currently in private testing.</dd></div><div><dt>The Host Portal</dt><dd>Accommodation representatives maintain listings that can appear in the app after review. Hikers book with hosts directly.</dd></div></dl></section>
  </InformationPage>;
}
