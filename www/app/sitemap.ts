import type { MetadataRoute } from 'next';
import { cyprusE4Stages } from '@/lib/cyprus-e4-data';
import { SITE_URL } from '@/lib/site';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: SITE_URL, changeFrequency: 'weekly', priority: 1 },
    {
      url: `${SITE_URL}/trails/cyprus-e4`,
      changeFrequency: 'weekly',
      priority: 0.9,
    },
    {
      url: `${SITE_URL}/trails/cyprus-e4/stages`,
      changeFrequency: 'weekly',
      priority: 0.85,
    },
    ...cyprusE4Stages.map((stage) => ({
      url: `${SITE_URL}/trails/cyprus-e4/stages/${stage.id}`,
      changeFrequency: 'monthly' as const,
      priority: 0.7,
    })),
    {
      url: `${SITE_URL}/get-inspired`,
      changeFrequency: 'weekly',
      priority: 0.7,
    },
    {
      url: `${SITE_URL}/become-a-host`,
      changeFrequency: 'monthly',
      priority: 0.8,
    },
    {
      url: `${SITE_URL}/get-involved`,
      changeFrequency: 'monthly',
      priority: 0.65,
    },
    {
      url: `${SITE_URL}/partnerships`,
      changeFrequency: 'monthly',
      priority: 0.65,
    },
    { url: `${SITE_URL}/about`, changeFrequency: 'monthly', priority: 0.6 },
    { url: `${SITE_URL}/help`, changeFrequency: 'monthly', priority: 0.6 },
  ];
}
