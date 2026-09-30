import type { ReactNode } from 'react';
import { PublicHeader } from '@/components/PublicHeader';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicContent } from '@/components/PublicContent';
import { publicHtmxNavigation } from '@/lib/htmx';

export function InformationPage({ label, title, introduction, children }: { label: string; title: string; introduction: string; children: ReactNode }) {
  return <><a className="skip-link" href="#main-content">Skip to content</a><PublicHeader /><PublicContent><main id="main-content" className="content-page information-page" tabIndex={-1} {...publicHtmxNavigation}><header className="simple-page-header section-shell"><p className="eyebrow">{label}</p><h1>{title}</h1><p>{introduction}</p></header><div className="section-shell information-content">{children}</div></main></PublicContent><PublicFooter /></>;
}
