import type { ReactNode } from 'react';

export function ActionLink({
  href,
  children,
}: {
  href: string;
  children: ReactNode;
}) {
  return (
    <a className="editorial-link action-link" href={href}>
      <span>{children}</span>
      <i aria-hidden="true" />
    </a>
  );
}
