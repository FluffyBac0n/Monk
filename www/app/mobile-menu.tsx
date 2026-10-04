import { NotifyButton } from '@/components/NotifyDialog';
import { disableHtmxNavigation } from '@/lib/htmx';

export default function MobileMenu() {
  return (
    <details className="mobile-menu" data-mobile-menu>
      <summary>Menu</summary>
      <nav aria-label="Mobile navigation">
        <a href="/#hikers">For Hikers</a>
        <a href="/#hosts">For Hosts</a>
        <a href="/trails/cyprus-e4">Explore Trails</a>
        <a href="/get-involved">Join Us</a>
        <a href="/about">About Us</a>
        <a className="header-portal-button" href="/portal" {...disableHtmxNavigation}>Host Portal</a>
        <NotifyButton className="header-portal-button">Notify Me</NotifyButton>
      </nav>
    </details>
  );
}
