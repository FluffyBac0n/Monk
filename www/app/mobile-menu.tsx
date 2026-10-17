import { NotifyButton } from '@/components/NotifyDialog';
import { disableHtmxNavigation } from '@/lib/htmx';

export default function MobileMenu() {
  return (
    <details className="mobile-menu" data-mobile-menu>
      <summary>Menu</summary>
      <nav aria-label="Mobile navigation">
        <a href="/trails/cyprus-e4">Explore Trails</a>
        <a href="/get-inspired">Get Inspired</a>
        <a href="/about">The Eurotrex Initiative</a>
        <a href="/get-involved">Community &amp; Support</a>
        <a href="/become-a-host">Become a Host</a>
        <a
          className="header-portal-button"
          href="/portal"
          {...disableHtmxNavigation}
        >
          Host Portal
        </a>
        <a
          className="header-portal-button"
          href="/trail-reports"
          {...disableHtmxNavigation}
        >
          Trail Reports
        </a>
        <NotifyButton className="header-portal-button">Notify Me</NotifyButton>
      </nav>
    </details>
  );
}
