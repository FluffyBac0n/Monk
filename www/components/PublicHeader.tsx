import Image from 'next/image';
import MobileMenu from '@/app/mobile-menu';
import { NotifyButton, NotifyDialog } from '@/components/NotifyDialog';
import { PublicHydrationBoundary } from '@/components/PublicHydrationBoundary';
import { TrailGuideSwitcher } from '@/components/TrailGuideSwitcher';
import { disableHtmxNavigation, publicHtmxNavigation } from '@/lib/htmx';

function LanguageControl() {
  const languages = [
    ['🇬🇧', 'English', 'EN'],
    ['🇩🇪', 'Deutsch', 'DE'],
    ['🇪🇸', 'Español', 'ES'],
    ['🇮🇹', 'Italiano', 'IT'],
    ['🇫🇷', 'Français', 'FR'],
  ];

  return (
    <details className="language-menu">
      <summary className="language-control" aria-label="Preview available languages">
        <svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="9" />
          <path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18" />
        </svg>
        <span>EN</span>
        <span className="language-chevron" aria-hidden="true">⌄</span>
      </summary>
      <div className="language-options">
        <div aria-label="Planned website languages" role="list">
          {languages.map(([flag, name, code], index) => (
            <div aria-current={index === 0 ? 'true' : undefined} className={`language-option${index === 0 ? ' current' : ''}`} key={code} role="listitem">
              <span aria-hidden="true">{flag}</span><strong>{name}</strong><small>{index === 0 ? code : 'Soon'}</small>
            </div>
          ))}
        </div>
        <p>Language selection coming soon</p>
      </div>
    </details>
  );
}

export function PublicHeader({ activeTrail }: { activeTrail?: string }) {
  // Public navigation persists while HTMX swaps the page content.
  return (
    <>
      <PublicHydrationBoundary />
      <header className="site-header" {...publicHtmxNavigation}>
        <div className="header-inner">
          <a className="brand" href="/" aria-label="EuroTrex home">
            <Image src="/eurotrex-wordmark-ui.webp" alt="EuroTrex" width={528} height={176} sizes="132px" />
          </a>
          <nav className="desktop-nav" aria-label="Primary navigation">
            <a href="/#hikers">For Hikers</a>
            <a href="/#hosts">For Hosts</a>
            <a href="/trails/cyprus-e4">Explore Trails</a>
            <a href="/get-involved">Join Us</a>
          </nav>
          <div className="header-actions">
            <a className="header-portal-button desktop-header-action" href="/portal" {...disableHtmxNavigation}>Host Portal</a>
            <NotifyButton className="header-portal-button desktop-header-action">Notify Me</NotifyButton>
            <LanguageControl />
            <MobileMenu />
          </div>
        </div>
      </header>
      <TrailGuideSwitcher activeTrail={activeTrail} />
      <NotifyDialog />
    </>
  );
}
