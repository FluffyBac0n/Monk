import type { ReactNode } from 'react';

export function PublicContent({ children }: { children: ReactNode }) {
  return (
    <div
      id="public-history"
      {...{
        'hx-history-elt': 'true',
        'hx-history': 'false',
      }}
    >
      {children}
    </div>
  );
}
