'use client';

import { reload, sendEmailVerification, type User } from 'firebase/auth';
import { useState } from 'react';
import { PortalHeader } from '@/components/PortalHeader';

function verificationError(caught: unknown) {
  const code = typeof caught === 'object' && caught && 'code' in caught ? String(caught.code) : '';
  if (code === 'auth/too-many-requests') return 'Too many verification emails were requested. Please wait before trying again.';
  if (code === 'auth/network-request-failed') return 'The connection was interrupted. Please try again.';
  return 'We could not complete that request. Please try again.';
}

export function AccountVerificationGate({ user, admin = false }: { user: User; admin?: boolean }) {
  const [busy, setBusy] = useState<'send' | 'check' | ''>('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function send() {
    setBusy('send'); setMessage(''); setError('');
    try {
      await sendEmailVerification(user);
      setMessage(`Verification email sent to ${user.email || 'your email address'}.`);
    } catch (caught) { setError(verificationError(caught)); }
    finally { setBusy(''); }
  }

  async function check() {
    setBusy('check'); setMessage(''); setError('');
    try {
      await reload(user);
      if (!user.emailVerified) {
        setError('This email has not been verified yet. Open the link in your email, then check again.');
        return;
      }
      await user.getIdToken(true);
      window.location.reload();
    } catch (caught) { setError(verificationError(caught)); }
    finally { setBusy(''); }
  }

  return (
    <main className="portal-page">
      <PortalHeader user={user} admin={admin} />
      <section className="access-card">
        <span>Protecting your account</span>
        <h1>Verify your email to continue.</h1>
        <p>We require a verified email before any host or administrator data can be opened.</p>
        {message && <p className="notice success" role="status">{message}</p>}
        {error && <p className="notice error" role="alert">{error}</p>}
        <div className="card-actions">
          <button className="button button-primary" disabled={Boolean(busy)} onClick={() => void send()}>{busy === 'send' ? 'Sending…' : 'Send verification email'}</button>
          <button className="button button-secondary" disabled={Boolean(busy)} onClick={() => void check()}>{busy === 'check' ? 'Checking…' : 'I have verified my email'}</button>
        </div>
      </section>
    </main>
  );
}
