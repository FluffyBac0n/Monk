'use client';

import { createUserWithEmailAndPassword, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth';
import { FormEvent, useState } from 'react';
import { auth } from '@/lib/firebase';
import { registerOwnerProfile } from '@/lib/accommodations';

type AuthPanelProps = {
  onNotice?: (message: string) => void;
  onError?: (message: string) => void;
};

function authErrorMessage(caught: unknown) {
  const code = typeof caught === 'object' && caught && 'code' in caught ? String(caught.code) : '';
  const messages: Record<string, string> = {
    'auth/email-already-in-use': 'An account already exists for this email. Sign in instead.',
    'auth/invalid-credential': 'The email or password is incorrect.',
    'auth/invalid-email': 'Enter a valid email address.',
    'auth/network-request-failed': 'The connection was interrupted. Please try again.',
    'auth/operation-not-allowed': 'Owner registration is temporarily unavailable.',
    'auth/too-many-requests': 'Too many attempts. Please wait a moment and try again.',
    'auth/weak-password': 'Use a password with at least eight characters.',
    'auth/user-disabled': 'This account has been disabled. Contact EuroTrex for help.',
  };
  return messages[code] || 'We could not complete that request. Please try again.';
}

export function AuthPanel({ onNotice, onError }: AuthPanelProps = {}) {
  const [mode, setMode] = useState<'signin' | 'register'>('signin');
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    setMessage('');
    const data = new FormData(event.currentTarget);
    const email = String(data.get('email') || '').trim();
    const password = String(data.get('password') || '');
    try {
      if (mode === 'register') {
        const result = await createUserWithEmailAndPassword(auth, email, password);
        try {
          await registerOwnerProfile(result.user, String(data.get('businessName') || '').trim());
          onNotice?.('Account created. You can now submit your accommodation.');
        } catch {
          const profileError = 'Your account was created, but the owner profile could not be completed. Please contact EuroTrex support.';
          setError(profileError);
          onError?.(profileError);
        }
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword() {
    const email = window.prompt('Enter your account email');
    if (!email) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      await sendPasswordResetEmail(auth, email.trim());
      setMessage('Password reset email sent.');
    } catch (caught) {
      setError(authErrorMessage(caught));
    } finally {
      setBusy(false);
    }
  }

  function switchMode(next: 'signin' | 'register') {
    setMode(next);
    setError('');
    setMessage('');
  }

  return (
    <section className="auth-card">
      <p className="eyebrow dark">ACCOMMODATION PARTNERS</p>
      <h1>{mode === 'signin' ? 'Welcome back.' : 'List your accommodation.'}</h1>
      <p className="muted">This account area is for accommodation owners. Every listing is reviewed before it appears in EuroTrex.</p>
      <div className="auth-tabs" role="tablist" aria-label="Account action">
        <button type="button" className={mode === 'signin' ? 'active' : ''} onClick={() => switchMode('signin')}>Sign in</button>
        <button type="button" className={mode === 'register' ? 'active' : ''} onClick={() => switchMode('register')}>Create owner account</button>
      </div>
      <form onSubmit={submit} className="form-grid single">
        {mode === 'register' && <label>Business or owner name<input name="businessName" autoComplete="organization" required /></label>}
        <label>Email address<input name="email" type="email" autoComplete="email" required /></label>
        <label>Password<input name="password" type="password" minLength={8} autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} required /></label>
        {error && <p className="form-message error" role="alert">{error}</p>}
        {message && <p className="form-message success" role="status">{message}</p>}
        <button className="button button-primary" disabled={busy}>{busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Create account'}</button>
      </form>
      {mode === 'signin' && <button type="button" className="text-button reset-link" disabled={busy} onClick={resetPassword}>Forgot your password?</button>}
    </section>
  );
}
