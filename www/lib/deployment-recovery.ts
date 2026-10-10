// Inline in <head> so recovery works even when an old JavaScript entry cannot load.
export const deploymentRecovery = `(() => {
  let recovering = false;
  function recover() {
    if (recovering || navigator.onLine === false) return;
    const url = new URL(window.location.href);
    const now = Date.now();
    const key = 'eurotrex:asset-recovery';
    const recent = Number(url.searchParams.get('_refresh'));
    if (recent && now - recent < 60000) return;
    try {
      if (now - Number(sessionStorage.getItem(key) || 0) < 60000) return;
      sessionStorage.setItem(key, String(now));
    } catch {}
    recovering = true;
    url.searchParams.set('_refresh', String(now));
    window.location.replace(url.href);
  }
  function isChunkError(error) {
    return /Failed to fetch dynamically imported module|Importing a module script failed|error loading dynamically imported module|Loading chunk [\\w-]+ failed|ChunkLoadError/i.test(String(error && (error.message || error)));
  }
  window.addEventListener('error', (event) => {
    const target = event.target;
    if (target && target.tagName === 'SCRIPT' && target.src) {
      const src = new URL(target.src, window.location.href);
      if (src.origin === window.location.origin && src.pathname.startsWith('/_next/static/')) recover();
    } else if (isChunkError(event.error || event.message)) recover();
  }, true);
  window.addEventListener('unhandledrejection', (event) => {
    if (isChunkError(event.reason)) recover();
  });
  window.addEventListener('vite:preloadError', (event) => {
    if (isChunkError(event.payload)) recover();
  });
})();`;
