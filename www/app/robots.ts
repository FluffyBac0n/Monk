import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  const base = process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site';
  return { rules: [{ userAgent: '*', allow: '/', disallow: ['/admin'] }], sitemap: `${base}/sitemap.xml` };
}
