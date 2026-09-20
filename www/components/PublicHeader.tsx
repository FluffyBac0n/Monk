import Image from 'next/image';
import MobileMenu from '@/app/mobile-menu';
import { HtmxRuntime } from '@/components/HtmxRuntime';
import { NotifyButton } from '@/components/NotifyDialog';
import { disableHtmxNavigation, publicHtmxNavigation } from '@/lib/htmx';

export function PublicHeader() {
  return (
    <header className="site-header" {...publicHtmxNavigation}>
      <HtmxRuntime />
      <div className="header-inner">
        <a className="brand" href="/" aria-label="EuroTrex home">
          <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} priority />
        </a>
        <span className="route-chip">E4 · Cyprus</span>
        <nav className="desktop-nav" aria-label="Primary navigation">
          <a href="/#hikers">For hikers</a>
          <a href="/trails/cyprus-e4">Trail guide</a>
          <a href="/#hosts">For hosts</a>
          <a href="/get-involved">Get involved</a>
          <a className="nav-host" href="/portal?mode=signin" {...disableHtmxNavigation}>Host sign in</a>
          <NotifyButton className="nav-primary">Notify me</NotifyButton>
        </nav>
        <MobileMenu />
      </div>
    </header>
  );
}
