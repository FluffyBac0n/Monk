import type { Metadata } from 'next';
import { InformationPage } from '@/components/InformationPage';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  alternates: { canonical: '/privacy' },
};

export default function Privacy() {
  return (
    <InformationPage label="Privacy Policy" title="Clear use of your data." introduction="How EuroTrex handles the information you share with us.">
        <div className="policy-copy">
          <p>EuroTrex Ltd operates this website. For privacy enquiries, contact <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>.</p>
          <p>The public EuroTrex website does not currently provide hiker accounts. It collects only the details people choose to send through app-update, involvement and accommodation-partner journeys.</p>
          <h2>App and launch updates</h2><p>When you ask to be notified, EuroTrex stores your email address, preferred mobile platform, selected trail where applicable, source page and submission time. We use this for the app or trail updates you requested. Re-entering the same email updates that preference without creating a duplicate subscription for the same trail.</p>
          <h2>Join us enquiries</h2><p>EuroTrex stores your name, email, optional organisation, selected interest, message, source page and submission time so the team can assess and reply to your enquiry. We also record whether you separately opted in to project updates. You do not need to opt in to receive a reply.</p>
          <h2>Accommodation partners</h2><p>For partner accounts, EuroTrex processes account email, business details, property information, draft progress, review history and administrative audit records. Approved public listing details may appear in the EuroTrex app.</p>
          <h2>Why we use it</h2><p>We use submitted information to respond, operate app-update and partner workflows, review accommodation, publish trail information, improve EuroTrex and prevent abuse. For form-abuse prevention, the site temporarily stores a pseudonymous, keyed identifier derived from the submitting network address; it automatically expires after a short rate-limit window and is not stored with the enquiry. We do not use these forms to process guest bookings or payments.</p>
          <h2>Your choices</h2><p>Accommodation partners can update their listing information through the host portal. To unsubscribe from project updates, or ask about access, correction, deletion or retention, contact <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a>.</p>
          <p className="legal-note">This notice describes the current private-testing website workflow and will be updated as EuroTrex services evolve.</p>
        </div>
    </InformationPage>
  );
}
