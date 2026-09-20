import type { Metadata } from 'next';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { publicHtmxNavigation } from '@/lib/htmx';

export const metadata: Metadata = {
  title: 'Privacy',
  alternates: { canonical: '/privacy' },
};

export default function Privacy() {
  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a><PublicHeader />
      <PublicContent>
      <main id="main-content" className="legal-page" tabIndex={-1} {...publicHtmxNavigation}>
        <a href="/" className="legal-brand">← EuroTrex</a>
        <article>
          <p className="eyebrow dark">PRIVACY</p><h1>Clear use of your data.</h1>
          <p>The public EuroTrex website does not currently provide hiker accounts. It collects only the details people choose to send through app-update, involvement and accommodation-partner journeys.</p>
          <h2>App and launch updates</h2><p>When you ask to be notified, EuroTrex stores your email address, preferred mobile platform, source page and submission time. We use this to contact you about relevant testing invitations and verified app-release links. Re-entering the same email does not create a duplicate notification record.</p>
          <h2>Get Involved enquiries</h2><p>EuroTrex stores your name, email, optional organisation, selected interest, message, source page and submission time so the team can assess and reply to your enquiry.</p>
          <h2>Accommodation partners</h2><p>For partner accounts, EuroTrex processes account email, business details, property information, draft progress, review history and administrative audit records. Approved public listing details may appear in the EuroTrex app.</p>
          <h2>Why we use it</h2><p>We use submitted information to respond, operate app-update and partner workflows, review accommodation, publish trail information, improve EuroTrex and prevent abuse. We do not use these forms to process guest bookings or payments.</p>
          <h2>Your choices</h2><p>Accommodation partners can update their listing information through the host portal. To unsubscribe from project updates, or ask about access, correction, deletion or retention, contact <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>.</p>
          <p className="legal-note">This notice describes the current private-testing website workflow and will be updated as EuroTrex services evolve.</p>
        </article>
      </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
