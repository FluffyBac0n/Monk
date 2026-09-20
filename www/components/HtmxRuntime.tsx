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

export function HtmxRuntime() {
  useEffect(() => {
    if (!document.querySelector('#public-history')) return;

    let disposed = false;
    let processNotifyDialog: EventListener | undefined;

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

    const handleAfterSettle = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      if (!(detail?.boosted || detail?.requestConfig?.boosted)) return;

      const anchor = window.location.hash.slice(1);
      if (anchor) {
        const target = document.getElementById(decodeURIComponent(anchor));
        const focusTarget = target?.querySelector<HTMLElement>('h1, h2, h3') || target;
        if (focusTarget) {
          if (!focusTarget.hasAttribute('tabindex')) focusTarget.setAttribute('tabindex', '-1');
          focusTarget.focus({ preventScroll: true });
          target?.scrollIntoView({ block: 'start' });
        }
      } else {
        document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true });
        window.scrollTo({ top: 0, behavior: 'instant' });
      }
    };

    const handleHistoryRestore = (event: Event) => {
      const detail = (event as CustomEvent<HtmxDetail>).detail;
      if (detail?.serverResponse) syncRouteHead(detail.serverResponse);
      document.querySelector<HTMLElement>('main')?.focus({ preventScroll: true });
    };

    const handleInput = (event: Event) => {
      const target = event.target;
      if (target instanceof HTMLInputElement && target.matches('[data-stage-filter]')) {
        filterStageDirectory(target);
      }
    };

    document.body.addEventListener('htmx:beforeSwap', handleBeforeSwap);
    document.body.addEventListener('htmx:afterRequest', handleAfterRequest);
    document.body.addEventListener('htmx:afterSettle', handleAfterSettle);
    document.body.addEventListener('htmx:historyRestore', handleHistoryRestore);
    document.addEventListener('input', handleInput);

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
      document.body.removeEventListener('htmx:afterSettle', handleAfterSettle);
      document.body.removeEventListener('htmx:historyRestore', handleHistoryRestore);
      document.removeEventListener('input', handleInput);
      if (processNotifyDialog) document.removeEventListener('eurotrex:notify-form-ready', processNotifyDialog);
    };
  }, []);

  return null;
}
