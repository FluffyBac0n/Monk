'use client';

import {
  createUserWithEmailAndPassword,
  deleteUser,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import { FormEvent, useEffect, useState } from 'react';
import { registerOwnerProfile } from '@/lib/accommodations';
import { auth } from '@/lib/firebase';

type AuthPanelProps = {
  admin?: boolean;
  trailReports?: boolean;
  embedded?: boolean;
  initialMode?: AccountMode;
};

type AccountMode = 'signin' | 'register';
type AuthMode = AccountMode | 'reset';

function authErrorCode(caught: unknown) {
  return typeof caught === 'object' && caught && 'code' in caught
    ? String(caught.code)
    : '';
}

function authErrorMessage(caught: unknown) {
  const messages: Record<string, string> = {
    'auth/email-already-in-use':
      'An account already exists for this email. Sign in instead.',
    'auth/invalid-credential': 'The email or password is incorrect.',
    'auth/invalid-email': 'Enter a valid email address.',
    'auth/network-request-failed':
      'The connection was interrupted. Please try again.',
    'auth/operation-not-allowed':
      'Host registration is temporarily unavailable.',
    'auth/too-many-requests':
      'Too many attempts. Please wait a moment and try again.',
    'auth/user-disabled':
      'This account has been disabled. Contact EuroTrex for help.',
    'auth/weak-password': 'Use a password with at least eight characters.',
  };
  return (
    messages[authErrorCode(caught)] ||
    'We could not complete that request. Please try again.'
  );
}

export function AuthPanel({
  admin = false,
  trailReports = false,
  embedded = false,
  initialMode = 'signin',
}: AuthPanelProps = {}) {
  const [mode, setMode] = useState<AuthMode>(initialMode);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (admin) return;
    const requested = new URLSearchParams(window.location.search).get('mode');
    const timer = window.setTimeout(() => {
      if (requested === 'register') setMode('register');
    }, 0);
    return () => window.clearTimeout(timer);
  }, [admin]);

  function clearFeedback() {
    setError('');
    setMessage('');
  }

  function switchAccountMode(next: AccountMode) {
    setMode(next);
    clearFeedback();
    const url = new URL(window.location.href);
    if (next === 'register') url.searchParams.set('mode', 'register');
    else url.searchParams.delete('mode');
    window.history.replaceState(
      window.history.state,
      '',
      `${url.pathname}${url.search}${url.hash}`
    );
  }

  async function submitAccount(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    clearFeedback();
    const data = new FormData(event.currentTarget);
    const email = String(data.get('email') || '').trim();
    const password = String(data.get('password') || '');
    const companyName = String(data.get('companyName') || '').trim();
    const firstName = String(data.get('firstName') || '').trim();
    const lastName = String(data.get('lastName') || '').trim();
    const confirmPassword = String(data.get('confirmPassword') || '');

    if (
      mode === 'register' &&
      !admin &&
      !trailReports &&
      (!firstName || !lastName)
    ) {
      setError('Enter your first name and surname.');
      setBusy(false);
      return;
    }
    if (
      mode === 'register' &&
      !admin &&
      !trailReports &&
      password !== confirmPassword
    ) {
      setError('The passwords do not match.');
      setBusy(false);
      return;
    }

    try {
      if (mode === 'register' && !admin) {
        const result = await createUserWithEmailAndPassword(
          auth,
          email,
          password
        );
        try {
          if (!trailReports)
            await registerOwnerProfile(result.user, {
              firstName,
              lastName,
              businessName: companyName,
            });
        } catch {
          await deleteUser(result.user).catch(() => undefined);
          throw new Error('profile-create-failed');
        }
        await sendEmailVerification(result.user).catch(() => undefined);
      } else {
        await signInWithEmailAndPassword(auth, email, password);
      }
      if (embedded) window.location.assign('/portal');
    } catch (caught) {
      setError(
        caught instanceof Error && caught.message === 'profile-create-failed'
          ? 'Your account could not be completed. Please try again.'
          : authErrorMessage(caught)
      );
    } finally {
      setBusy(false);
    }
  }

  async function submitReset(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    clearFeedback();
    const email = String(
      new FormData(event.currentTarget).get('email') || ''
    ).trim();

    try {
      await sendPasswordResetEmail(auth, email);
      setMessage(
        'If an account exists for that email, a password reset link is on its way.'
      );
    } catch (caught) {
      const code = authErrorCode(caught);
      if (code === 'auth/user-not-found') {
        setMessage(
          'If an account exists for that email, a password reset link is on its way.'
        );
      } else {
        setError(authErrorMessage(caught));
      }
    } finally {
      setBusy(false);
    }
  }

  function openReset() {
    setMode('reset');
    clearFeedback();
  }

  const heading = trailReports
    ? mode === 'register'
      ? 'Create your ERA account.'
      : mode === 'reset'
        ? 'Reset your password.'
        : 'ERA Login.'
    : admin
      ? 'Administrator sign in.'
      : mode === 'register'
        ? 'Create your host account.'
        : mode === 'reset'
          ? 'Reset your password.'
          : 'Welcome back.';
  const introduction = trailReports
    ? 'Verify your email, then ask your administrator to assign your trails.'
    : admin
      ? 'Sign in with your authorised EuroTrex administrator account.'
      : mode === 'register'
        ? 'Add your name and verify your email. Company or organisation details are optional. Host access is reviewed within 1–3 days; property listings are reviewed separately after submission.'
        : mode === 'reset'
          ? 'Enter your account email and we will send you a secure reset link.'
          : 'Sign in to manage your accommodation listings and saved drafts.';

  return (
    <section className="auth-card">
      {!trailReports && <p className="eyebrow">
        {admin ? 'EUROTREX OPERATIONS' : 'ACCOMMODATION PARTNERS'}
      </p>}
      {embedded ? <h2>{heading}</h2> : <h1>{heading}</h1>}
      <p>{introduction}</p>

      {!admin && mode !== 'reset' && (
        <div
          className="auth-tabs"
          role="group"
          aria-label={
            trailReports ? 'Trail team account action' : 'Host account action'
          }
        >
          <button
            type="button"
            aria-pressed={mode === 'signin'}
            className={mode === 'signin' ? 'active' : ''}
            onClick={() => switchAccountMode('signin')}
          >
            Sign in
          </button>
          <button
            type="button"
            aria-pressed={mode === 'register'}
            className={mode === 'register' ? 'active' : ''}
            onClick={() => switchAccountMode('register')}
          >
            Create account
          </button>
        </div>
      )}

      {mode === 'reset' ? (
        <form
          onSubmit={submitReset}
          className="form-grid single auth-reset-form"
        >
          <label>
            <span className="field-label">
              Email address{' '}
              <span className="required-marker" aria-hidden="true">
                *
              </span>
            </span>
            <input
              name="email"
              type="email"
              autoComplete="email"
              required
              autoFocus
            />
          </label>
          {error && (
            <p className="form-message error" role="alert">
              {error}
            </p>
          )}
          {message && (
            <p className="form-message success" role="status">
              {message}
            </p>
          )}
          <button className="button button-primary" disabled={busy}>
            {busy ? 'Sending…' : 'Send reset link'}
          </button>
        </form>
      ) : (
        <form onSubmit={submitAccount} className="form-grid single">
          {mode === 'register' && !admin && !trailReports && (
            <>
              <label>
                <span className="field-label">
                  Name{' '}
                  <span className="required-marker" aria-hidden="true">
                    *
                  </span>
                </span>
                <input
                  name="firstName"
                  autoComplete="given-name"
                  maxLength={80}
                  required
                />
              </label>
              <label>
                <span className="field-label">
                  Surname{' '}
                  <span className="required-marker" aria-hidden="true">
                    *
                  </span>
                </span>
                <input
                  name="lastName"
                  autoComplete="family-name"
                  maxLength={80}
                  required
                />
              </label>
              <label>
                <span className="field-label">
                  Company name{' '}
                  <span className="optional-marker">(Optional)</span>
                </span>
                <input
                  name="companyName"
                  autoComplete="organization"
                  maxLength={160}
                />
              </label>
            </>
          )}
          <label>
            <span className="field-label">
              Email address{' '}
              <span className="required-marker" aria-hidden="true">
                *
              </span>
            </span>
            <input
              name="email"
              type="email"
              autoComplete="email"
              maxLength={254}
              required
            />
          </label>
          <label>
            <span className="field-label">
              Password{' '}
              <span className="required-marker" aria-hidden="true">
                *
              </span>
            </span>
            <input
              name="password"
              type="password"
              minLength={8}
              autoComplete={
                mode === 'register' ? 'new-password' : 'current-password'
              }
              required
            />
          </label>
          {mode === 'register' && !admin && !trailReports && (
            <label>
              <span className="field-label">
                Confirm Password{' '}
                <span className="required-marker" aria-hidden="true">
                  *
                </span>
              </span>
              <input
                name="confirmPassword"
                type="password"
                minLength={8}
                autoComplete="new-password"
                required
              />
            </label>
          )}
          {error && (
            <p className="form-message error" role="alert">
              {error}
            </p>
          )}
          {message && (
            <p className="form-message success" role="status">
              {message}
            </p>
          )}
          <button className="button button-primary" disabled={busy}>
            {busy
              ? 'Please wait…'
              : mode === 'register'
                ? 'Create account'
                : 'Sign in'}
          </button>
        </form>
      )}

      {mode === 'signin' && (
        <button
          type="button"
          className="text-button reset-link"
          disabled={busy}
          onClick={openReset}
        >
          Forgot your password?
        </button>
      )}
      {mode === 'reset' && (
        <button
          type="button"
          className="text-button reset-link"
          disabled={busy}
          onClick={() => switchAccountMode('signin')}
        >
          Back to sign in
        </button>
      )}
      {!admin && !trailReports && mode === 'signin' && (
        <p className="auth-invitation-help">
          Want to list a stay?{' '}
          <a
            href="/portal?mode=register"
            onClick={(event) => {
              event.preventDefault();
              switchAccountMode('register');
            }}
          >
            Create your host account
          </a>
          .
        </p>
      )}
    </section>
  );
}
