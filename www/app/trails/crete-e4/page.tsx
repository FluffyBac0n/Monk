import type { Metadata } from 'next';
import { FutureTrailPreview } from '@/components/FutureTrailPreview';

export const metadata: Metadata = {
  title: 'Crete E4 trail guide preview',
  description: 'Preview the coming-soon EuroTrex guide to the Crete E4 while its route, stage points, services and trail conditions are verified.',
  alternates: { canonical: '/trails/crete-e4' },
  robots: { index: false, follow: true },
  openGraph: {
    type: 'website',
    url: '/trails/crete-e4',
    title: 'Crete E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Crete E4.',
    images: [{ url: '/crete-e4-placeholder.webp', width: 1672, height: 941, alt: 'Concept preview for the future Crete E4 trail guide' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Crete E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Crete E4.',
    images: ['/crete-e4-placeholder.webp'],
  },
};

export default function CreteE4Preview() {
  return (
    <FutureTrailPreview
      activeTrail="crete-e4"
      trailName="Crete · E4"
      title="Crete’s E4 is joining the journey."
      introduction="A new EuroTrex trail guide is taking shape across Crete. This preview gives the route a home while we prepare information hikers can genuinely rely on."
      imageSrc="/crete-e4-placeholder.webp"
      imageAlt="Concept image of a rugged Mediterranean mountain path in Crete"
    />
  );
}
