'use client';

import Image from 'next/image';
import Link from 'next/link';
import { signOut, type User } from 'firebase/auth';
import { auth } from '@/lib/firebase';

export function PortalHeader({ user, admin = false }: { user?: User | null; admin?: boolean }) {
  return (
    <header className="portal-header">
      <Link className="brand" href="/" aria-label="EuroTrex home">
        <Image src="/eurotrex-wordmark.png" alt="EuroTrex" width={2172} height={724} priority />
      </Link>
      <div className="portal-nav">
        {user && <span className="account-email">{user.email}</span>}
        {admin ? <Link href="/portal">Owner portal</Link> : <Link href="/admin">Admin</Link>}
        <Link href="/">Website</Link>
        {user && <button className="text-button" onClick={() => signOut(auth)}>Sign out</button>}
      </div>
    </header>
  );
}
