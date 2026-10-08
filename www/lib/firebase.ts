'use client';

import { getApp, getApps, initializeApp } from 'firebase/app';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFirestoreEmulator, getFirestore } from 'firebase/firestore';
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from 'firebase/app-check';

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || 'AIzaSyDxLgyIQfsdCy3RqnonbjnV2nc3S6O7Tgk',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || 'eurotrex.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'eurotrex',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || 'eurotrex.firebasestorage.app',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '893185124081',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || '1:893185124081:web:87409fbc7f8e15966a6b50',
};

const localEmulators = process.env.NODE_ENV === 'development'
  && process.env.NEXT_PUBLIC_REPORTS_EMULATOR === 'true';
const app = getApps().length ? getApp() : initializeApp(localEmulators
  ? {...firebaseConfig, projectId: 'demo-eurotrex', apiKey: 'demo-key', storageBucket: 'demo-eurotrex.appspot.com'}
  : firebaseConfig);

// The site key is public and restricted to our published website domain.
// Keep one instance across development hot reloads; SSR has no browser attestation.
const appCheckScope = globalThis as typeof globalThis & { eurotrexAppCheck?: boolean; eurotrexEmulators?: boolean };
if (typeof window !== 'undefined' && !localEmulators && !appCheckScope.eurotrexAppCheck) {
  initializeAppCheck(app, {
    provider: new ReCaptchaEnterpriseProvider('6LcuPOItAAAAAO-lEBudmQUXnLbqx66JZYxB1ulb'),
    isTokenAutoRefreshEnabled: true,
  });
  appCheckScope.eurotrexAppCheck = true;
}

export const auth = getAuth(app);
export const db = getFirestore(app);

export const reportFunctions = getFunctions(app, 'europe-west1');
if (localEmulators && typeof window !== 'undefined' && !appCheckScope.eurotrexEmulators) {
  if (!['localhost', '127.0.0.1'].includes(window.location.hostname)) throw new Error('Emulator preview must use localhost.');
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  connectFunctionsEmulator(reportFunctions, '127.0.0.1', 5001);
  appCheckScope.eurotrexEmulators = true;
}
