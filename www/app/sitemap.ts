import type { MetadataRoute } from 'next';
import { cyprusE4Stages } from '@/lib/cyprus-e4-data';
import { SITE_URL } from '@/lib/site';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: SITE_URL, changeFrequency: 'weekly', priority: 1 },
    { url: `${SITE_URL}/trails/cyprus-e4`, changeFrequency: 'weekly', priority: .9 },
    { url: `${SITE_URL}/trails/cyprus-e4/stages`, changeFrequency: 'weekly', priority: .85 },
    ...cyprusE4Stages.map((stage) => ({ url: `${SITE_URL}/trails/cyprus-e4/stages/${stage.id}`, changeFrequency: 'monthly' as const, priority: .7 })),
    { url: `${SITE_URL}/get-involved`, changeFrequency: 'monthly', priority: .65 },
    { url: `${SITE_URL}/partnerships`, changeFrequency: 'monthly', priority: .65 },
  ];
}
