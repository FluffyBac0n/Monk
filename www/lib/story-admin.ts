import { firebaseConfig } from './firebase-config';

export class StoryAccessError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
  }
}

// Firebase validates the ID token before any decoded claim is used. Firestore
// then confirms the same existing administrator role used by the owner portal.
export async function requireStoryAdmin(request: Request): Promise<string> {
  const token = request.headers
    .get('authorization')
    ?.match(/^Bearer (\S+)$/)?.[1];
  if (!token || token.length > 8000)
    throw new StoryAccessError(
      401,
      'Sign in with your Eurotrex administrator account.'
    );
  const emulator =
    process.env.NODE_ENV === 'development' &&
    process.env.NEXT_PUBLIC_REPORTS_EMULATOR === 'true';
  const project = emulator ? 'demo-eurotrex' : firebaseConfig.projectId;
  const authBase = emulator
    ? 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1'
    : 'https://identitytoolkit.googleapis.com/v1';
  const lookup = await fetch(
    `${authBase}/accounts:lookup?key=${encodeURIComponent(emulator ? 'demo-key' : firebaseConfig.apiKey)}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ idToken: token }),
      signal: AbortSignal.timeout(8000),
    }
  );
  if (!lookup.ok)
    throw new StoryAccessError(
      401,
      'Your session could not be verified. Sign in again.'
    );
  const account = (await lookup.json()) as {
    users?: { localId: string; emailVerified?: boolean; disabled?: boolean }[];
  };
  const user = account.users?.[0];
  if (!user?.localId || !user.emailVerified || user.disabled)
    throw new StoryAccessError(
      403,
      'A verified administrator account is required.'
    );
  let claims: Record<string, unknown>;
  try {
    claims = JSON.parse(
      atob(token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))
    );
  } catch {
    throw new StoryAccessError(401, 'Your session could not be verified.');
  }
  if (
    claims.sub !== user.localId ||
    claims.aud !== project ||
    claims.iss !== `https://securetoken.google.com/${project}`
  )
    throw new StoryAccessError(
      401,
      'Your session belongs to a different project.'
    );
  const firestoreBase = emulator
    ? 'http://127.0.0.1:8080/v1'
    : 'https://firestore.googleapis.com/v1';
  const membership = await fetch(
    `${firestoreBase}/projects/${encodeURIComponent(project)}/databases/(default)/documents/admins/${encodeURIComponent(user.localId)}`,
    {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(8000),
    }
  );
  if (!membership.ok && !(membership.status === 404 && claims.admin === true))
    throw new StoryAccessError(
      403,
      'Eurotrex administrator access is required.'
    );
  return user.localId;
}
