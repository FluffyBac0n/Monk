import type { ReactNode } from 'react';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicContent } from '@/components/PublicContent';
import { publicHtmxNavigation } from '@/lib/htmx';

export function InformationPage({ label, title, titleClassName, introduction, children }: { label?: string; title: string; titleClassName?: string; introduction?: string; children: ReactNode }) {
  return <><a className="skip-link" href="#main-content">Skip to content</a><PublicHeader /><PublicContent><main id="main-content" className="content-page information-page" tabIndex={-1} {...publicHtmxNavigation}><header className="simple-page-header section-shell">{label ? <p className="eyebrow">{label}</p> : null}<h1 className={titleClassName}>{title}</h1>{introduction ? <p>{introduction}</p> : null}</header><div className="section-shell information-content">{children}</div></main></PublicContent><PublicFooter /></>;
}
