import type { Metadata } from 'next';
import { FutureTrailPreview } from '@/components/FutureTrailPreview';

export const metadata: Metadata = {
  title: 'Crete-E4 trail guide preview',
  description: 'A preview of the planned EuroTrex Crete-E4 guide. Route details and services are not yet available.',
  alternates: { canonical: '/trails/crete-e4' },
  robots: { index: false, follow: true },
  openGraph: {
    type: 'website',
    url: '/trails/crete-e4',
    title: 'Crete-E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Crete-E4.',
    images: [{ url: '/crete-samaria.webp', width: 1280, height: 795, alt: 'Samaria Gorge in Crete' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Crete-E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Crete-E4.',
    images: ['/crete-samaria.webp'],
  },
};

export default function CreteE4Preview() {
  return (
    <FutureTrailPreview
      activeTrail="crete-e4"
      trailName="Crete-E4"
      title="Crete-E4 is joining the journey."
      introduction="Crete is part of our plans for EuroTrex. Discover the destination here and ask to hear when a reviewed trail guide is ready."
      imageSrc="/crete-samaria.webp"
      imageAlt="Limestone slopes and pine trees in Samaria Gorge, Crete"
    />
  );
}
