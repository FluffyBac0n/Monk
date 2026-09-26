import type { ReactNode } from 'react';

export function PublicContent({ children }: { children: ReactNode }) {
  return (
    <div
      id="public-history"
      data-runtime-owner="public-htmx"
      {...{
        'hx-history-elt': 'true',
        'hx-history': 'false',
      }}
    >
      {children}
    </div>
  );
}
