'use client';

import Link from 'next/link';
import { useRef } from 'react';

export default function MobileMenu() {
  const menuRef = useRef<HTMLDetailsElement>(null);

  function closeMenu() {
    if (menuRef.current) menuRef.current.open = false;
  }

  return (
    <details className="mobile-menu" ref={menuRef}>
      <summary>Menu</summary>
      <nav aria-label="Mobile navigation">
        <a href="#hikers" onClick={closeMenu}>For hikers</a>
        <a href="#hosts" onClick={closeMenu}>For hosts</a>
        <a href="#project" onClick={closeMenu}>The project</a>
        <a href="#involved" onClick={closeMenu}>Get involved</a>
        <Link href="/portal" onClick={closeMenu}>Host portal</Link>
      </nav>
    </details>
  );
}
