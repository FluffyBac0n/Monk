// Public Firebase application identifiers, shared by browser and server verification.
export const firebaseConfig = {
  apiKey:
    process.env.NEXT_PUBLIC_FIREBASE_API_KEY ||
    'AIzaSyDxLgyIQfsdCy3RqnonbjnV2nc3S6O7Tgk',
  authDomain:
    process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || 'eurotrex.firebaseapp.com',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'eurotrex',
  storageBucket:
    process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET ||
    'eurotrex.firebasestorage.app',
  messagingSenderId:
    process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '893185124081',
  appId:
    process.env.NEXT_PUBLIC_FIREBASE_APP_ID ||
    '1:893185124081:web:87409fbc7f8e15966a6b50',
};
