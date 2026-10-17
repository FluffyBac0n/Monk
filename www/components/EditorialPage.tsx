import Image from 'next/image';
import type { ReactNode } from 'react';
import { PublicHeader } from './PublicHeader';
import { PublicFooter } from './PublicFooter';
import { PublicContent } from './PublicContent';
import { publicHtmxNavigation } from '@/lib/htmx';

export function EditorialPage({
  eyebrow,
  title,
  introduction,
  image,
  imageAlt,
  hero,
  pageClass = '',
  clientNavigation = false,
  children,
}: {
  eyebrow?: string;
  title?: string;
  introduction?: string;
  image?: string;
  imageAlt?: string;
  hero?: ReactNode;
  pageClass?: string;
  clientNavigation?: boolean;
  children: ReactNode;
}) {
  return (
    <>
      <a className="skip-link" href="#main-content">
        Skip to content
      </a>
      <PublicHeader />
      <PublicContent>
        <main
          id="main-content"
          className={`content-page editorial-page ${pageClass}`.trim()}
          tabIndex={-1}
          {...publicHtmxNavigation}
          {...(clientNavigation ? { 'hx-boost': 'false' } : {})}
        >
          {hero || (
            <header className="editorial-hero section-shell">
              <div>
                <p className="eyebrow">{eyebrow}</p>
                <h1>{title}</h1>
                <p className="editorial-lead">{introduction}</p>
              </div>
              {image && (
                <figure>
                  <Image
                    src={image}
                    alt={imageAlt || ''}
                    fill
                    priority
                    sizes="(max-width: 760px) 100vw, 45vw"
                  />
                </figure>
              )}
            </header>
          )}
          {children}
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
