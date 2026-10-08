import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/site';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: '*', allow: '/', disallow: ['/admin', '/admin/', '/portal', '/portal/', '/trail-reports', '/trail-reports/'] }],
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
