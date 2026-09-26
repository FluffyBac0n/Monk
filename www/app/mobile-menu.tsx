import { NotifyButton } from '@/components/NotifyDialog';
import { disableHtmxNavigation } from '@/lib/htmx';

export default function MobileMenu() {
  return (
    <details className="mobile-menu" data-mobile-menu>
      <summary>Menu</summary>
      <nav aria-label="Mobile navigation">
        <a href="/#hikers">For hikers</a>
        <a href="/trails/cyprus-e4">Explore trails</a>
        <a href="/#hosts">For hosts</a>
        <a href="/get-involved">Get involved</a>
        <a className="mobile-host" href="/portal?mode=signin" {...disableHtmxNavigation}>Host Portal</a>
        <NotifyButton className="mobile-primary">Notify me</NotifyButton>
      </nav>
    </details>
  );
}
