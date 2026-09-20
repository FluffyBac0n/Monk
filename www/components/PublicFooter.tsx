import Image from 'next/image';
import { disableHtmxNavigation, publicHtmxNavigation } from '@/lib/htmx';

export function PublicFooter() {
  return (
    <footer className="site-footer" {...publicHtmxNavigation}>
      <div className="section-shell footer-compact">
        <nav className="footer-nav" aria-label="Footer navigation">
          <div><strong>Explore</strong><a href="/#hikers">Hiker app</a><a href="/trails/cyprus-e4">Cyprus E4 guide</a><a href="/#faq">Questions</a></div>
          <div><strong>Partners</strong><a href="/portal?mode=register" {...disableHtmxNavigation}>List your stay</a><a href="/portal?mode=signin" {...disableHtmxNavigation}>Host sign in</a><a href="/partnerships">Partnerships</a></div>
          <div><strong>Information</strong><a href="/get-involved">Get involved</a><a href="/privacy">Privacy</a><a href="/partner-terms">Partner policy</a></div>
        </nav>
        <p className="footer-legal">© {new Date().getFullYear()} EuroTrex. Apple and the Apple logo are trademarks of Apple Inc. Google Play and the Google Play logo are trademarks of Google LLC.</p>
        <div className="funding-marks" aria-label="Project funders" role="group">
          <div className="funding-mark">
            <Image src="/eu-flag-color.png" alt="European Union flag" width={1247} height={853} />
            <span>Co-funded by the<br /><strong>European Union</strong></span>
          </div>
          <div className="funding-mark">
            <Image src="/republic-of-cyprus-emblem.png" alt="Republic of Cyprus emblem" width={817} height={812} />
            <span>Co-funded by the<br /><strong>Republic of Cyprus</strong></span>
          </div>
        </div>
      </div>
    </footer>
  );
}
