import { NextResponse, type NextRequest } from 'next/server';
import { isLocalHttpPreview } from '@/lib/local-preview';

const contentSecurityPolicy = [
  "default-src 'self'",
  "base-uri 'self'",
  "object-src 'none'",
  "frame-ancestors 'none'",
  "form-action 'self'",
  "script-src 'self' 'unsafe-inline'",
  "script-src-attr 'none'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self' data:",
  "connect-src 'self' https://*.googleapis.com https://*.firebaseio.com wss://*.firebaseio.com https://*.firebaseapp.com",
  "frame-src 'self' https://eurotrex.firebaseapp.com",
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
  const localHttp = isLocalHttpPreview(request.url);
  securityHeaders.forEach(([name, value]) => {
    // Safari upgrades localhost assets too. Our local server has no TLS;
    // keep every other protection and retain HTTPS enforcement elsewhere.
    if (localHttp && name === 'Strict-Transport-Security') return;
    response.headers.set(name, localHttp && name === 'Content-Security-Policy'
      ? value.replace('; upgrade-insecure-requests', '')
      : value);
  });
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|.*\\.(?:css|gif|ico|jpeg|jpg|js|png|svg|txt|webp)$).*)'],
};
