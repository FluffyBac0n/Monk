import {env} from 'cloudflare:workers';
export const dynamic = 'force-dynamic';
export async function GET() {
  const token = (env as unknown as Record<string, unknown>).MAPBOX_PUBLIC_ACCESS_TOKEN;
  if (typeof token !== 'string' || !token.startsWith('pk.')) return Response.json({error: 'Map configuration unavailable'}, {status: 503});
  // Mapbox public tokens are intentionally delivered to the browser, never secret tokens.
  return Response.json({accessToken: token}, {headers: {'Cache-Control': 'private, no-store'}});
}
