import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site'),
  title: {
    default: 'EuroTrex — Find your way on Europe’s long-distance trails',
    template: '%s · EuroTrex',
  },
  description: 'Explore Europe’s long-distance trails with accessible guidance, offline maps, stage planning and trusted places to stay—starting with the Cyprus E4.',
  applicationName: 'EuroTrex',
  icons: { icon: '/icon.png', apple: '/icon.png' },
  openGraph: {
    type: 'website',
    locale: 'en_CY',
    siteName: 'EuroTrex',
    title: 'EuroTrex — Find your way on Europe’s long-distance trails',
    description: 'Accessible trail guidance, planning and trusted stays—starting with the Cyprus E4.',
    images: [{ url: '/og.png', width: 1672, height: 941, alt: 'EuroTrex — Find your way on Europe’s long-distance trails' }],
  },
  twitter: { card: 'summary_large_image', images: ['/og.png'] },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
