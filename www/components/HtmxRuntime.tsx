'use client';

import { useEffect } from 'react';

type HtmxDetail = {
  boosted?: boolean;
  elt?: Element;
  serverResponse?: string;
  shouldSwap?: boolean;
  xhr?: XMLHttpRequest;
  requestConfig?: {
    boosted?: boolean;
    elt?: Element;
  };
};

const routeHeadSelectors = [
  'meta[name="description"]',
  'meta[name="robots"]',
  'meta[property^="og:"]',
  'meta[name^="twitter:"]',
  'link[rel="canonical"]',
];

function syncRouteHead(responseText: string) {
  const incoming = new DOMParser().parseFromString(responseText, 'text/html');
  if (!incoming.querySelector('main')) return;
  if (incoming.title) document.title = incoming.title;

  for (const selector of routeHeadSelectors) {
    document.head.querySelectorAll(selector).forEach((node) => node.remove());
    incoming.head.querySelectorAll(selector).forEach((node) => document.head.insertAdjacentHTML('beforeend', node.outerHTML));
  }
}

function filterStageDirectory(input: HTMLInputElement) {
  const directory = input.closest<HTMLElement>('.stage-directory');
  if (!directory) return;

  const needle = input.value.trim().toLocaleLowerCase();
  const rows = Array.from(directory.querySelectorAll<HTMLElement>('[data-stage-search]'));
  let visible = 0;

  for (const row of rows) {
    const matches = !needle || (row.dataset.stageSearch || '').includes(needle);
    row.hidden = !matches;
    if (matches) visible += 1;
  }

  const count = directory.querySelector<HTMLElement>('[data-stage-count]');
  if (count) count.textContent = `Showing ${visible} of ${rows.length} stage points`;

  const empty = directory.querySelector<HTMLElement>('[data-stage-empty]');
  if (empty) {
    empty.hidden = visible !== 0;
    const query = empty.querySelector<HTMLElement>('[data-stage-query]');
    if (query) query.textContent = input.value.trim();
  }
}

function setTrailSlide(slideshow: HTMLElement, requestedIndex: number) {
  const panels = Array.from(slideshow.querySelectorAll<HTMLElement>('[data-trail-slide-panel]'));
  if (!panels.length) return;

  const nextIndex = ((requestedIndex % panels.length) + panels.length) % panels.length;
  slideshow.dataset.activeSlide = String(nextIndex);

  panels.forEach((panel, index) => {
    const active = index === nextIndex;
    panel.classList.toggle('is-active', active);
    panel.setAttribute('aria-hidden', String(!active));
  });

  slideshow.querySelectorAll<HTMLButtonElement>('[data-trail-slide-go]').forEach((button) => {
    if (Number(button.dataset.trailSlideGo) === nextIndex) button.setAttribute('aria-current', 'true');
    else button.removeAttribute('aria-current');
  });

  const status = slideshow.querySelector<HTMLElement>('[data-trail-slide-status]');
  if (status) {
    const label = panels[nextIndex].dataset.trailSlideLabel;
    status.textContent = `Image ${nextIndex + 1} of ${panels.length}${label ? `: ${label}` : ''}`;
  }
}

export function HtmxRuntime() {
  useEffect(() => {
    if (!document.querySelector('#public-history')) return;

    let disposed = false;
    let processNotifyDialog: EventListener | undefined;
    const countFrames = new Map<HTMLElement, number>();
    const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    const animateCount = (element: HTMLElement) => {
      const target = Number(element.dataset.countUp);
      if (!Number.isFinite(target)) return;
      const startedAt = performance.now();
      const duration = 1050;

      const step = (now: number) => {
        const progress = Math.min((now - startedAt) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        element.textContent = Math.round(target * eased).toLocaleString('en-GB');
        if (progress < 1) {
          countFrames.set(element, window.requestAnimationFrame(step));
        } else {
          countFrames.delete(element);
        }
      };

      countFrames.set(element, window.requestAnimationFrame(step));
    };

    const countObserver = !reduceMotion && 'IntersectionObserver' in window
      ? new IntersectionObserver((entries, observer) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue;
          const element = entry.target as HTMLElement;
          observer.unobserve(element);
          animateCount(element);
        }
      }, { threshold: 0.35 })
      : null;

    const initializeCountUps = (root: ParentNode = document) => {
      root.querySelectorAll<HTMLElement>('[data-count-up]:not([data-count-up-ready])').forEach((element) => {
        element.dataset.countUpReady = 'true';
        const target = Number(element.dataset.countUp);
        if (!Number.isFinite(target)) return;
        if (!countObserver) {
          element.textContent = target.toLocaleString('en-GB');
          return;
        }
        element.textContent = '0';
        countObserver.observe(element);
      });
    };

    const syncTrailSwitcher = () => {
      const activeTrail = document.querySelector<HTMLElement>('main[data-trail-guide]')?.dataset.trailGuide;

      document.querySelectorAll<HTMLAnchorElement>('.trail-switcher-item[data-trail-id]').forEach((item) => {
        const active = item.dataset.trailId === activeTrail;
        item.classList.toggle('active', active);
        if (active) item.setAttribute('aria-current', 'true');
        else item.removeAttribute('aria-current');
      });
    };

    const revealActiveTrail = (animate = false) => {
      const active = document.querySelector<HTMLElement>('.trail-switcher-item.active');
      const scroller = active?.closest<HTMLElement>('.trail-switcher');
      if (!active || !scroller) return;

      const activeBounds = active.getBoundingClientRect();
      const scrollerBounds = scroller.getBoundingClientRect();
      if (activeBounds.left >= scrollerBounds.left && activeBounds.right <= scrollerBounds.right) return;

      active.scrollIntoView({
        behavior: animate && !reduceMotion ? 'smooth' : 'auto',
        block: 'nearest',
        inline: 'center',
      });
    };

    const handleBeforeSwap = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      const status = detail?.xhr?.status || 0;
      if (
        (detail?.boosted || detail?.requestConfig?.boosted)
        && detail?.shouldSwap !== false
        && status >= 200
        && status < 400
        && detail.xhr?.responseText
      ) {
        syncRouteHead(detail.xhr.responseText);
      }
    };

    const handleAfterRequest = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      const source = detail?.requestConfig?.elt || detail?.elt;
      if (!(source instanceof HTMLFormElement) || !source.matches('[data-interest-form]')) return;

      const feedback = source.querySelector<HTMLElement>('.form-feedback');
      if (!feedback) return;
      feedback.innerHTML = detail.xhr?.responseText
        || '<p class="form-message error" role="alert">We could not save this right now. Please try again.</p>';

      if (detail.xhr?.getResponseHeader('X-EuroTrex-Interest-Success') === 'true') {
        source.dataset.submitted = 'true';
        feedback.querySelector<HTMLElement>('[role="status"]')?.focus();
      }
    };

    const handleAfterSwap = () => {
      initializeCountUps(document);
      syncTrailSwitcher();
    };

    const handleAfterSettle = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      if (!(detail?.boosted || detail?.requestConfig?.boosted)) return;
      revealActiveTrail(true);

      const anchor = window.location.hash.slice(1);
      if (anchor) {
        const target = document.getElementById(decodeURIComponent(anchor));
        target?.scrollIntoView({ block: 'start' });
      } else {
        document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true });
        window.scrollTo({ top: 0, behavior: 'instant' });
      }
    };

    const handleHistoryRestore = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      if (detail?.serverResponse) syncRouteHead(detail.serverResponse);
      initializeCountUps(document);
      syncTrailSwitcher();
      revealActiveTrail();
      document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true });
    };

    const handleInput = (event: Event) => {
      const target = event.target;
      if (target instanceof HTMLInputElement && target.matches('[data-stage-filter]')) {
        filterStageDirectory(target);
      }
    };

    const handleClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Element)) return;
      const control = target.closest<HTMLButtonElement>('[data-trail-slide-go], [data-trail-slide-next], [data-trail-slide-previous]');
      const slideshow = control?.closest<HTMLElement>('[data-trail-slideshow]');
      if (!control || !slideshow) return;

      const currentIndex = Number(slideshow.dataset.activeSlide || 0);
      if (control.dataset.trailSlideGo !== undefined) {
        setTrailSlide(slideshow, Number(control.dataset.trailSlideGo));
      } else {
        setTrailSlide(slideshow, currentIndex + (control.hasAttribute('data-trail-slide-next') ? 1 : -1));
      }
    };

    document.body.addEventListener('htmx:beforeSwap', handleBeforeSwap);
    document.body.addEventListener('htmx:afterRequest', handleAfterRequest);
    document.body.addEventListener('htmx:afterSwap', handleAfterSwap);
    document.body.addEventListener('htmx:afterSettle', handleAfterSettle);
    document.body.addEventListener('htmx:historyRestore', handleHistoryRestore);
    document.addEventListener('input', handleInput);
    document.addEventListener('click', handleClick);
    initializeCountUps(document);
    syncTrailSwitcher();
    revealActiveTrail();

    void import('htmx.org').then(({ default: htmx }) => {
      if (disposed) return;
      try {
        window.sessionStorage.removeItem('htmx-history-cache');
      } catch {
        // History still works through live HTMX fetches when storage is unavailable.
      }
      htmx.config.historyCacheSize = 0;
      htmx.process(document.body);

      processNotifyDialog = () => {
        const dialog = document.querySelector<HTMLDialogElement>('.notify-dialog');
        if (dialog) htmx.process(dialog);
      };
      document.addEventListener('eurotrex:notify-form-ready', processNotifyDialog);
      if (document.querySelector<HTMLDialogElement>('.notify-dialog[open]')) processNotifyDialog(new Event('ready'));
    });

    return () => {
      disposed = true;
      document.body.removeEventListener('htmx:beforeSwap', handleBeforeSwap);
      document.body.removeEventListener('htmx:afterRequest', handleAfterRequest);
      document.body.removeEventListener('htmx:afterSwap', handleAfterSwap);
      document.body.removeEventListener('htmx:afterSettle', handleAfterSettle);
      document.body.removeEventListener('htmx:historyRestore', handleHistoryRestore);
      document.removeEventListener('input', handleInput);
      document.removeEventListener('click', handleClick);
      countObserver?.disconnect();
      countFrames.forEach((frame) => window.cancelAnimationFrame(frame));
      if (processNotifyDialog) document.removeEventListener('eurotrex:notify-form-ready', processNotifyDialog);
    };
  }, []);

  return null;
}
