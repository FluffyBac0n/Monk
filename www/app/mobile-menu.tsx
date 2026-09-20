'use client';

import { useRef } from 'react';
import { NotifyButton } from '@/components/NotifyDialog';
import { disableHtmxNavigation } from '@/lib/htmx';

export default function MobileMenu() {
  const menuRef = useRef<HTMLDetailsElement>(null);

  function closeMenu() {
    if (menuRef.current) menuRef.current.open = false;
  }

  return (
    <details className="mobile-menu" ref={menuRef}>
      <summary>Menu</summary>
      <nav aria-label="Mobile navigation">
        <a href="/#hikers" onClick={closeMenu}>For hikers</a>
        <a href="/trails/cyprus-e4" onClick={closeMenu}>Trail guide</a>
        <a href="/#hosts" onClick={closeMenu}>For hosts</a>
        <a href="/get-involved" onClick={closeMenu}>Get involved</a>
        <a href="/portal?mode=signin" onClick={closeMenu} {...disableHtmxNavigation}>Host sign in</a>
        <NotifyButton className="mobile-primary" onOpen={closeMenu}>Notify me</NotifyButton>
      </nav>
    </details>
  );
}
