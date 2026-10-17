import { getPublicTrail } from '@/lib/public-trail-data';
import { publicNoticeHtml } from '@/lib/public-notices';

export async function GET() {
  const trail = await getPublicTrail().catch(() => null);
  return new Response(
    publicNoticeHtml(trail?.issues || [], trail?.issuesAvailable || false),
    {
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'cache-control': 'no-store',
      },
    }
  );
}
