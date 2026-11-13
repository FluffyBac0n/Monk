'use client';
import {createContext, useContext, useEffect, useMemo, useRef, type ReactNode} from 'react';

// Private drafts and photo Files stay in memory, scoped to the signed-in workspace.
const Drafts = createContext<Map<string, unknown> | null>(null);
export function IncidentDrafts({children}: {children: ReactNode}) {
  const drafts = useRef(new Map<string, unknown>());
  useEffect(() => {
    const warn = (event: BeforeUnloadEvent) => {
      if (!drafts.current.size) return;
      event.preventDefault(); event.returnValue = '';
    };
    window.addEventListener('beforeunload', warn);
    return () => {window.removeEventListener('beforeunload', warn); drafts.current.clear();};
  }, []);
  return <Drafts.Provider value={drafts.current}>{children}</Drafts.Provider>;
}
export function useIncidentDraft<T>(key: string) {
  const shared = useContext(Drafts), fallback = useRef(new Map<string, unknown>());
  const drafts = shared || fallback.current;
  return useMemo(() => ({
    read: () => drafts.get(key) as T | undefined,
    save: (value: T) => {drafts.set(key, value);},
    clear: () => {drafts.delete(key);},
  }), [drafts, key]);
}
