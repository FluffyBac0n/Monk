import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = {
  title: 'Privacy',
  alternates: { canonical: '/privacy' },
  robots: { index: false, follow: false },
};

export default function Privacy() {
  return <main className="legal-page"><Link href="/" className="legal-brand">← EuroTrex</Link><article><p className="eyebrow dark">PRIVACY</p><h1>Clear use of partner data.</h1><p>The public EuroTrex website does not provide hiker accounts. Accommodation partners sign in so they can submit and maintain their own listings.</p><h2>What we process</h2><p>For partner accounts, EuroTrex processes account email, business details, property information, review history and administrative audit records. Approved public listing details may appear in the EuroTrex app.</p><h2>Why we use it</h2><p>We use this information to authenticate owners, review submissions, publish trail accommodation and prevent abuse.</p><h2>Your choices</h2><p>Accommodation partners can update their listing information through the host portal. For questions about access, correction, deletion or retention, contact <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>.</p><p className="legal-note">This page describes the current website partner-data workflow and will be updated as EuroTrex services evolve.</p></article></main>;
}
