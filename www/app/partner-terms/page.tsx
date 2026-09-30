import type { Metadata } from 'next';
import { InformationPage } from '@/components/InformationPage';

export const metadata: Metadata = {
  title: 'Partner Policy',
  alternates: { canonical: '/partner-terms' },
  robots: { index: false, follow: false },
};

export default function PartnerTerms() {
  return (
    <InformationPage label="Partner Policy" title="Accurate listings. Safer trails." introduction="Standards for accommodation partners on EuroTrex.">
          <div className="policy-copy">
            <p>Accommodation partners must be authorised to represent the property and provide accurate, current information.</p>
            <h2>Listing standards</h2><ul><li>Prices, availability, contact details and map coordinates must be truthful.</li><li>The selected trail and nearest stage point must reasonably reflect the property’s location.</li><li>Descriptions must not contain deceptive claims, prohibited content or third-party material used without permission.</li><li>Owners must promptly update seasonal closures, booking details and material service changes.</li></ul>
            <h2>Review and removal</h2><p>EuroTrex may verify, request changes, reject, suspend or remove a listing to protect hikers, comply with law or enforce these standards. Administrative decisions are recorded in an audit log.</p>
            <h2>Owner responsibility</h2><p>Approval is not an endorsement or booking guarantee. Owners remain responsible for their accommodation, guests, licences, taxes and compliance obligations.</p>
            <p className="legal-note">Questions about eligibility or these standards? Contact <a href="mailto:info@eurotrex.eu">info@eurotrex.eu</a> before submitting a listing.</p>
          </div>
    </InformationPage>
  );
}
