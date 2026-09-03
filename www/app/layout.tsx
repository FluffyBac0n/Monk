import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site'),
  title: {
    default: 'EuroTrex — Explore the E4 Cyprus trail',
    template: '%s · EuroTrex',
  },
  description: 'Plan and navigate the Cyprus E4 with offline maps, elevation, stages and trusted trail accommodation.',
  applicationName: 'EuroTrex',
  icons: { icon: '/icon.png', apple: '/icon.png' },
  openGraph: {
    type: 'website',
    locale: 'en_CY',
    siteName: 'EuroTrex',
    title: 'EuroTrex — Explore the E4 Cyprus trail',
    description: 'Offline maps, tailored stage planning and trusted trail accommodation for the Cyprus E4.',
    images: [{ url: '/og.png', width: 1672, height: 941, alt: 'EuroTrex — Explore the E4 Cyprus trail' }],
  },
  twitter: { card: 'summary_large_image', images: ['/og.png'] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
