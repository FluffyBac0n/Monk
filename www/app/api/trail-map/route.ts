import { env } from 'cloudflare:workers';
import { getPublicTrail } from '@/lib/public-trail-data';
import { trailMapImageUrl } from '@/lib/trail-map-image';
import { SITE_URL } from '@/lib/site';

let cached: {
  key: string;
  image: Promise<{ body: ArrayBuffer; type: string }>;
} | null = null;
export async function GET() {
  try {
    const token = (env as unknown as Record<string, unknown>)
      .MAPBOX_PUBLIC_ACCESS_TOKEN;
    if (typeof token !== 'string' || !token.startsWith('pk.'))
      throw new Error('Map unavailable');
    const trail = await getPublicTrail();
    if (!trail.geometryAvailable) throw new Error('Route unavailable');
    const url = trailMapImageUrl(trail.points, token);
    if (cached?.key !== url) {
      const image = fetch(url, {
        headers: { Referer: SITE_URL },
        signal: AbortSignal.timeout(12000),
      })
        .then(async (response) => {
          const type = response.headers.get('content-type') || '';
          if (!response.ok || !type.startsWith('image/'))
            throw new Error('Map unavailable');
          return { body: await response.arrayBuffer(), type };
        })
        .catch((error) => {
          if (cached?.key === url) cached = null;
          throw error;
        });
      cached = { key: url, image };
    }
    const image = await cached.image;
    return new Response(image.body, {
      headers: {
        'Content-Type': image.type,
        'Cache-Control': 'private, max-age=60',
        'X-Content-Type-Options': 'nosniff',
      },
    });
  } catch {
    return Response.json(
      { error: 'The route map is temporarily unavailable.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } }
    );
  }
}
