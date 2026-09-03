import type { Metadata } from 'next';
import Link from 'next/link';

export const metadata: Metadata = { title: 'Privacy' };

export default function Privacy() {
  return <main className="legal-page"><Link href="/" className="legal-brand">← EuroTrex</Link><article><p className="eyebrow dark">PRIVACY</p><h1>Clear use of partner data.</h1><p>The public EuroTrex website does not provide hiker accounts. Accommodation partners sign in so they can submit and maintain their own listings.</p><h2>What we process</h2><p>For partner accounts, EuroTrex processes account email, business details, property information, review history and administrative audit records. Approved public listing details may appear in the EuroTrex app.</p><h2>Why and how long</h2><p>We use this information to authenticate owners, review submissions, publish trail accommodation and prevent abuse. Retention periods and contact details must be finalised before public launch.</p><p className="legal-note">This MVP privacy notice is a product placeholder and requires legal review before public launch.</p></article></main>;
}
