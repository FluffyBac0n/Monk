'use client';

import { createUserWithEmailAndPassword, sendPasswordResetEmail, signInWithEmailAndPassword } from 'firebase/auth';
import { FormEvent, useState } from 'react';
import { auth } from '@/lib/firebase';
import { registerOwnerProfile } from '@/lib/accommodations';

export function AuthPanel() {
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
        await registerOwnerProfile(result.user, String(data.get('businessName') || '').trim());
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
    } catch (caught) {
      setError(caught instanceof Error ? caught.message.replace('Firebase: ', '') : 'We could not sign you in.');
    } finally {
      setBusy(false);
    }
  }

  async function resetPassword() {
    const email = window.prompt('Enter your account email');
    if (!email) return;
    try {
      await sendPasswordResetEmail(auth, email.trim());
      setMessage('Password reset email sent.');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message.replace('Firebase: ', '') : 'Reset failed.');
    }
  }

  return (
    <section className="auth-card">
      <p className="eyebrow dark">ACCOMMODATION PARTNERS</p>
      <h1>{mode === 'signin' ? 'Welcome back.' : 'List your accommodation.'}</h1>
      <p className="muted">This account area is for verified accommodation owners. Hikers can explore EuroTrex in the mobile app.</p>
      <div className="auth-tabs" role="tablist" aria-label="Account action">
        <button className={mode === 'signin' ? 'active' : ''} onClick={() => setMode('signin')}>Sign in</button>
        <button className={mode === 'register' ? 'active' : ''} onClick={() => setMode('register')}>Create owner account</button>
      </div>
      <form onSubmit={submit} className="form-grid single">
        {mode === 'register' && <label>Business or owner name<input name="businessName" autoComplete="organization" required /></label>}
        <label>Email address<input name="email" type="email" autoComplete="email" required /></label>
        <label>Password<input name="password" type="password" minLength={8} autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} required /></label>
        {error && <p className="form-message error" role="alert">{error}</p>}
        {message && <p className="form-message success" role="status">{message}</p>}
        <button className="button button-primary" disabled={busy}>{busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Create account'}</button>
      </form>
      {mode === 'signin' && <button className="text-button reset-link" onClick={resetPassword}>Forgot your password?</button>}
    </section>
  );
}
