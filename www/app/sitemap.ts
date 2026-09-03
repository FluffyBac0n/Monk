import type { MetadataRoute } from 'next';

export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.NEXT_PUBLIC_SITE_URL || 'https://eurotrex.groovy-newt-8196.chatgpt.site';
  return ['', '/portal', '/partner-terms', '/privacy'].map((path) => ({ url: `${base}${path}`, changeFrequency: path ? 'monthly' : 'weekly', priority: path ? 0.6 : 1 }));
}
