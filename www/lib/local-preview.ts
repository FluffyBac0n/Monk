/** Only explicit loopback HTTP origins may omit HTTPS-only response headers. */
export function isLocalHttpPreview(url: string): boolean {
  const { protocol, hostname } = new URL(url);
  return protocol === 'http:' && ['localhost', '127.0.0.1', '[::1]'].includes(hostname);
}
