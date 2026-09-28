import { NextResponse } from 'next/server';

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

export function proxy() {
  const response = NextResponse.next();
  securityHeaders.forEach(([name, value]) => response.headers.set(name, value));
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|.*\\.(?:css|gif|ico|jpeg|jpg|js|png|svg|txt|webp)$).*)'],
};
