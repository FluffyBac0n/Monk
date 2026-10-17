'use client';

import { AuthPanel } from './AuthPanel';
import { useAuthState } from '@/lib/use-auth';

export function HostAccount() {
  const { user } = useAuthState();
  if (user)
    return (
      <section className="auth-card">
        <h2>Your host account.</h2>
        <p>
          Continue to the Host Portal to verify your email, check access or
          manage your listings.
        </p>
        <a className="button button-primary" href="/portal" hx-boost="false">
          Open Host Portal
        </a>
      </section>
    );
  return <AuthPanel embedded initialMode="register" />;
}
