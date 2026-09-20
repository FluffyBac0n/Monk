'use client';

import Image from 'next/image';
import { signOut, type User } from 'firebase/auth';
import { auth } from '@/lib/firebase';

export function PortalHeader({ user, admin = false, canAccessAdmin = false }: { user?: User | null; admin?: boolean; canAccessAdmin?: boolean }) {
  return (
    <header className="portal-header">
      <a className="brand" href="/" aria-label="EuroTrex home">
        <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} priority />
      </a>
      <div className="portal-nav">
        {user && <span className="account-email">{user.email}</span>}
        {admin ? <a href="/portal">Owner portal</a> : canAccessAdmin ? <a href="/admin">Admin</a> : null}
        <a href="/">Website</a>
        {user && <button className="text-button" onClick={() => signOut(auth)}>Sign out</button>}
      </div>
    </header>
  );
}
