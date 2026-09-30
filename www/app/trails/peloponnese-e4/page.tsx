import type { Metadata } from 'next';
import { FutureTrailPreview } from '@/components/FutureTrailPreview';

export const metadata: Metadata = {
  title: 'Peloponnese-E4 trail guide preview',
  description: 'A preview of the planned EuroTrex Peloponnese-E4 guide. Route details and services are not yet available.',
  alternates: { canonical: '/trails/peloponnese-e4' },
  robots: { index: false, follow: true },
  openGraph: {
    type: 'website',
    url: '/trails/peloponnese-e4',
    title: 'Peloponnese-E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Peloponnese-E4.',
    images: [{ url: '/peloponnese-taygetos.webp', width: 1280, height: 853, alt: 'Taygetos mountains in the Peloponnese' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Peloponnese-E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Peloponnese-E4.',
    images: ['/peloponnese-taygetos.webp'],
  },
};

export default function PeloponneseE4Preview() {
  return (
    <FutureTrailPreview
      activeTrail="peloponnese-e4"
      trailName="Peloponnese-E4"
      title="The Peloponnese-E4 is coming into view."
      introduction="The Peloponnese is part of our plans for EuroTrex. Discover the destination here and ask to hear when a reviewed trail guide is ready."
      imageSrc="/peloponnese-taygetos.webp"
      imageAlt="Walkers below the rocky Taygetos mountain ridge in the Peloponnese"
    />
  );
}
