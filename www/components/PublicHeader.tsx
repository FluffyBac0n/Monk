import Image from 'next/image';
import MobileMenu from '@/app/mobile-menu';
import { HtmxRuntime } from '@/components/HtmxRuntime';
import { NotifyButton } from '@/components/NotifyDialog';
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
              <span aria-hidden="true">{flag}</span><strong>{name}</strong><small>{code}</small>
            </div>
          ))}
        </div>
        <p>Language selection coming soon</p>
      </div>
    </details>
  );
}

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
          <a className="nav-host" href="/portal?mode=signin" {...disableHtmxNavigation}>Host Portal</a>
          <NotifyButton className="nav-primary">Notify me</NotifyButton>
        </nav>
        <LanguageControl />
        <MobileMenu />
      </div>
    </header>
  );
}
