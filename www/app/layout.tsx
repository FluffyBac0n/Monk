import type { Metadata } from 'next';
import { NotifyDialog } from '@/components/NotifyDialog';
import { SITE_URL } from '@/lib/site';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: 'EuroTrex — Cyprus E4 trail app and route planner',
    template: '%s · EuroTrex',
  },
  description: 'Plan and navigate the Cyprus E4 with offline route guidance, flexible stages, elevation context and practical trail-side stays.',
  applicationName: 'EuroTrex',
  keywords: ['Cyprus E4', 'E4 trail app', 'Cyprus hiking', 'offline hiking maps', 'long-distance trails Europe', 'EuroTrex'],
  alternates: { canonical: '/' },
  icons: { icon: '/eurotrex-app-icon.png', apple: '/eurotrex-app-icon.png' },
  openGraph: {
    type: 'website',
    locale: 'en_CY',
    url: '/',
    siteName: 'EuroTrex',
    title: 'EuroTrex — Cyprus E4 trail app and route planner',
    description: 'Offline route guidance, flexible stage planning and trail-side stays for the Cyprus E4.',
    images: [{ url: '/og.png', width: 1672, height: 941, alt: 'EuroTrex guide to the Cyprus E4 trail' }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'EuroTrex — Cyprus E4 trail app',
    description: 'Plan and navigate the Cyprus E4 with offline guidance, flexible stages and practical stays.',
    images: ['/og.png'],
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}<NotifyDialog /></body></html>;
}
