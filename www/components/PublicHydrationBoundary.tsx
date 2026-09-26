'use client';

import { useEffect } from 'react';

export function PublicHydrationBoundary() {
  useEffect(() => {
    document.documentElement.dataset.publicReactHydrated = 'true';
    document.dispatchEvent(new Event('eurotrex:public-react-hydrated'));
  }, []);

  return <span data-public-hydration-boundary hidden />;
}
