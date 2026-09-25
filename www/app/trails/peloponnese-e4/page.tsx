import type { Metadata } from 'next';
import { FutureTrailPreview } from '@/components/FutureTrailPreview';

export const metadata: Metadata = {
  title: 'Peloponnese E4 trail guide preview',
  description: 'Preview the coming-soon EuroTrex guide to the Peloponnese E4 while its route, stage points, services and trail conditions are verified.',
  alternates: { canonical: '/trails/peloponnese-e4' },
  robots: { index: false, follow: true },
  openGraph: {
    type: 'website',
    url: '/trails/peloponnese-e4',
    title: 'Peloponnese E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Peloponnese E4.',
    images: [{ url: '/peloponnese-e4-placeholder.webp', width: 1672, height: 941, alt: 'Concept preview for the future Peloponnese E4 trail guide' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Peloponnese E4 trail guide preview',
    description: 'A first look at the coming-soon EuroTrex guide to the Peloponnese E4.',
    images: ['/peloponnese-e4-placeholder.webp'],
  },
};

export default function PeloponneseE4Preview() {
  return (
    <FutureTrailPreview
      activeTrail="peloponnese-e4"
      trailName="Peloponnese · E4"
      title="The Peloponnese E4 is coming into view."
      introduction="We are preparing a future EuroTrex guide for the Peloponnese E4. This preview is an early look while the route is checked carefully on the way to a dependable trail guide."
      imageSrc="/peloponnese-e4-placeholder.webp"
      imageAlt="Concept image of a mountain walking trail through the Peloponnese landscape"
    />
  );
}
