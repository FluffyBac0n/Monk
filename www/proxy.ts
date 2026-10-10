import { NextResponse, type NextRequest } from 'next/server';
import { isLocalHttpPreview } from '@/lib/local-preview';

const contentSecurityPolicy = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'none'",
  "form-action 'self'",
  "script-src 'self' 'unsafe-inline' https://www.google.com/recaptcha/ https://www.gstatic.com/recaptcha/",
  "script-src-attr 'none'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob: https://api.mapbox.com",
  "font-src 'self' data:",
  "connect-src 'self' https://api.mapbox.com https://events.mapbox.com https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.firebaseapp.com https://europe-west1-eurotrex.cloudfunctions.net https://www.google.com/recaptcha/",
  "frame-src 'self' https://eurotrex.firebaseapp.com https://www.google.com/recaptcha/ https://recaptcha.google.com/recaptcha/",
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  'upgrade-insecure-requests',
].join('; ');

const securityHeaders = [
  ['Content-Security-Policy', contentSecurityPolicy],
  ['Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=(), usb=(), browsing-topics=()'],
  ['Referrer-Policy', 'strict-origin-when-cross-origin'],
  ['Strict-Transport-Security', 'max-age=31536000; includeSubDomains'],
  ['X-Content-Type-Options', 'nosniff'],
  ['X-Frame-Options', 'DENY'],
] as const;

export function proxy(request: NextRequest) {
  const response = NextResponse.next();
  // Documents point to build-specific chunks. Revalidate them after publication
  // while the excluded, content-hashed static assets keep their normal caching.
  if (!request.nextUrl.pathname.startsWith('/api/')) {
    response.headers.set('Cache-Control', 'private, no-cache, max-age=0, must-revalidate');
    response.headers.set('CDN-Cache-Control', 'no-store');
    response.headers.set('Cloudflare-CDN-Cache-Control', 'no-store');
  }
  const localHttp = isLocalHttpPreview(request.url);
  securityHeaders.forEach(([name, value]) => {
    // Safari upgrades localhost assets too. Our local server has no TLS;
    // keep every other protection and retain HTTPS enforcement elsewhere.
    if (localHttp && name === 'Strict-Transport-Security') return;
    let header = localHttp && name === 'Content-Security-Policy'
      ? value.replace('; upgrade-insecure-requests', '') : value;
    if (localHttp && name === 'Content-Security-Policy' && process.env.NODE_ENV === 'development'
      && process.env.NEXT_PUBLIC_REPORTS_EMULATOR === 'true') {
      header = header.replace("connect-src 'self'", "connect-src 'self' http://127.0.0.1:9099 http://127.0.0.1:8080 http://127.0.0.1:5001");
    }
    response.headers.set(name, header);
  });
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|.*\\.(?:css|gif|ico|jpeg|jpg|js|png|svg|txt|webp)$).*)'],
};
