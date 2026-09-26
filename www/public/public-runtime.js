function startPublicRuntime(htmx) {
  'use strict';

  if (window.__eurotrexPublicRuntime || !document.querySelector('#public-history')) return;

  if (!htmx) {
    console.error('EuroTrex public runtime could not start because HTMX is unavailable.');
    return;
  }

  window.__eurotrexPublicRuntime = true;

  const routeHeadSelectors = [
    'meta[name="description"]',
    'meta[name="robots"]',
    'meta[property^="og:"]',
    'meta[name^="twitter:"]',
    'link[rel="canonical"]',
  ];
  const countFrames = new Map();
  const slideshowTimers = new Map();
  const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
  const slideshowDelay = 6000;
  const nativePushState = History.prototype.pushState;
  const nativeReplaceState = History.prototype.replaceState;
  let reduceMotion = motionPreference.matches;
  let bridgedPushState;
  let bridgedReplaceState;
  let countObserver;
  let dialogOpener;

  function isHtmxHistoryState(state) {
    return typeof state === 'object' && state !== null && state.htmx === true;
  }

  function ensureHtmxHistoryBridge() {
    if (
      window.history.pushState === bridgedPushState
      && window.history.replaceState === bridgedReplaceState
    ) return;

    const frameworkPushState = window.history.pushState;
    const frameworkReplaceState = window.history.replaceState;

    bridgedPushState = function pushState(data, unused, url) {
      if (isHtmxHistoryState(data)) {
        return nativePushState.call(window.history, data, unused, url);
      }
      return frameworkPushState.call(window.history, data, unused, url);
    };

    bridgedReplaceState = function replaceState(data, unused, url) {
      if (isHtmxHistoryState(data)) {
        return nativeReplaceState.call(window.history, data, unused, url);
      }
      return frameworkReplaceState.call(window.history, data, unused, url);
    };

    window.history.pushState = bridgedPushState;
    window.history.replaceState = bridgedReplaceState;
  }

  function handlePopState(event) {
    if (!isHtmxHistoryState(event.state)) return;

    ensureHtmxHistoryBridge();
    const htmxPopState = window.onpopstate;
    if (typeof htmxPopState !== 'function') return;

    // HTMX restores the persistent public content region. Stop Next's router
    // from rendering the same history entry a second time.
    htmxPopState.call(window, event);
  }

  function syncRouteHead(responseText) {
    const incoming = new DOMParser().parseFromString(responseText, 'text/html');
    if (!incoming.querySelector('main')) return;

    if (incoming.title) document.title = incoming.title;

    for (const selector of routeHeadSelectors) {
      document.head.querySelectorAll(selector).forEach((node) => node.remove());
      // Vinext streams route metadata near the end of <body>; DOMParser does
      // not consistently hoist those nodes back into <head>.
      incoming.querySelectorAll(selector).forEach((node) => {
        document.head.insertAdjacentHTML('beforeend', node.outerHTML);
      });
    }
  }

  function filterStageDirectory(input) {
    const directory = input.closest('.stage-directory');
    if (!directory) return;

    const needle = input.value.trim().toLowerCase();
    const rows = Array.from(directory.querySelectorAll('[data-stage-search]'));
    let visible = 0;

    for (const row of rows) {
      const matches = !needle || (row.dataset.stageSearch || '').includes(needle);
      row.hidden = !matches;
      if (matches) visible += 1;
    }

    const count = directory.querySelector('[data-stage-count]');
    if (count) count.textContent = `Showing ${visible} of ${rows.length} stage points`;

    const empty = directory.querySelector('[data-stage-empty]');
    if (empty) {
      empty.hidden = visible !== 0;
      const query = empty.querySelector('[data-stage-query]');
      if (query) query.textContent = input.value.trim();
    }
  }

  function setTrailSlide(slideshow, requestedIndex, announce) {
    const panels = Array.from(slideshow.querySelectorAll('[data-trail-slide-panel]'));
    if (!panels.length || !Number.isFinite(requestedIndex)) return;

    const nextIndex = ((requestedIndex % panels.length) + panels.length) % panels.length;
    slideshow.dataset.activeSlide = String(nextIndex);

    panels.forEach((panel, index) => {
      const active = index === nextIndex;
      panel.classList.toggle('is-active', active);
      panel.setAttribute('aria-hidden', String(!active));
    });

    slideshow.querySelectorAll('[data-trail-slide-go]').forEach((button) => {
      if (Number(button.dataset.trailSlideGo) === nextIndex) {
        button.setAttribute('aria-current', 'true');
      } else {
        button.removeAttribute('aria-current');
      }
    });

    const status = slideshow.querySelector('[data-trail-slide-status]');
    if (status && announce) {
      const label = panels[nextIndex].dataset.trailSlideLabel;
      status.textContent = `Image ${nextIndex + 1} of ${panels.length}${label ? `: ${label}` : ''}`;
    }
  }

  function stopTrailSlideshow(slideshow) {
    const timer = slideshowTimers.get(slideshow);
    if (timer !== undefined) window.clearTimeout(timer);
    slideshowTimers.delete(slideshow);
  }

  function scheduleTrailSlideshow(slideshow) {
    stopTrailSlideshow(slideshow);
    if (
      reduceMotion
      || slideshow.dataset.userPaused === 'true'
      || document.hidden
      || !slideshow.isConnected
      || slideshow.matches(':hover')
      || slideshow.contains(document.activeElement)
    ) return;

    const timer = window.setTimeout(() => {
      slideshowTimers.delete(slideshow);
      if (!slideshow.isConnected) return;

      if (
        reduceMotion
        || slideshow.dataset.userPaused === 'true'
        || document.hidden
        || slideshow.matches(':hover')
        || slideshow.contains(document.activeElement)
      ) {
        scheduleTrailSlideshow(slideshow);
        return;
      }

      const currentIndex = Number(slideshow.dataset.activeSlide || 0);
      setTrailSlide(slideshow, currentIndex + 1, false);
      scheduleTrailSlideshow(slideshow);
    }, slideshowDelay);

    slideshowTimers.set(slideshow, timer);
  }

  function initializeTrailSlideshows(root) {
    slideshowTimers.forEach((_timer, slideshow) => {
      if (!slideshow.isConnected) stopTrailSlideshow(slideshow);
    });

    root.querySelectorAll('[data-trail-slideshow]').forEach((slideshow) => {
      const currentIndex = Number(slideshow.dataset.activeSlide || 0);
      setTrailSlide(slideshow, currentIndex, false);
      syncSlideshowToggle(slideshow);
      slideshow.dataset.trailSlideshowReady = 'true';
      if (!slideshowTimers.has(slideshow)) scheduleTrailSlideshow(slideshow);
    });
  }

  function syncSlideshowToggle(slideshow) {
    const toggle = slideshow.querySelector('[data-trail-slide-toggle]');
    if (!(toggle instanceof HTMLButtonElement)) return;

    const paused = slideshow.dataset.userPaused === 'true';
    toggle.hidden = reduceMotion;
    toggle.setAttribute('aria-pressed', String(paused));
    toggle.setAttribute('aria-label', paused ? 'Play slideshow' : 'Pause slideshow');
    const icon = toggle.querySelector('[aria-hidden="true"]');
    if (icon) icon.textContent = paused ? '▶' : 'Ⅱ';
  }

  function animateCount(element) {
    const target = Number(element.dataset.countUp);
    if (!Number.isFinite(target)) return;

    const startedAt = performance.now();
    const duration = 1050;

    function step(now) {
      if (!element.isConnected || reduceMotion) {
        element.textContent = target.toLocaleString('en-GB');
        countFrames.delete(element);
        return;
      }

      const progress = Math.min((now - startedAt) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      element.textContent = Math.round(target * eased).toLocaleString('en-GB');

      if (progress < 1) {
        countFrames.set(element, window.requestAnimationFrame(step));
      } else {
        countFrames.delete(element);
      }
    }

    countFrames.set(element, window.requestAnimationFrame(step));
  }

  function getCountObserver() {
    if (reduceMotion || !('IntersectionObserver' in window)) return null;
    if (countObserver) return countObserver;

    countObserver = new IntersectionObserver((entries, observer) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        observer.unobserve(entry.target);
        animateCount(entry.target);
      }
    }, { threshold: 0.35 });

    return countObserver;
  }

  function initializeCountUps(root) {
    root.querySelectorAll('[data-count-up]:not([data-count-up-ready])').forEach((element) => {
      element.dataset.countUpReady = 'true';
      const target = Number(element.dataset.countUp);
      if (!Number.isFinite(target)) return;

      const observer = getCountObserver();
      if (!observer) {
        element.textContent = target.toLocaleString('en-GB');
        return;
      }

      element.textContent = '0';
      observer.observe(element);
    });
  }

  function syncTrailSwitcher() {
    const activeTrail = document.querySelector('main[data-trail-guide]')?.dataset.trailGuide;

    document.querySelectorAll('.trail-switcher-item[data-trail-id]').forEach((item) => {
      const active = item.dataset.trailId === activeTrail;
      item.classList.toggle('active', active);
      if (active) item.setAttribute('aria-current', 'true');
      else item.removeAttribute('aria-current');
    });
  }

  function revealActiveTrail() {
    const active = document.querySelector('.trail-switcher-item.active');
    const scroller = active?.closest('.trail-switcher');
    if (!active || !scroller) return;

    const activeBounds = active.getBoundingClientRect();
    const scrollerBounds = scroller.getBoundingClientRect();
    if (activeBounds.left >= scrollerBounds.left && activeBounds.right <= scrollerBounds.right) return;

    active.scrollIntoView({ behavior: 'auto', block: 'nearest', inline: 'center' });
  }

  function closeMobileMenus() {
    document.querySelectorAll('details[data-mobile-menu]').forEach((menu) => {
      menu.open = false;
      menu.querySelectorAll('details').forEach((details) => { details.open = false; });
    });
  }

  function abortInterestRequest(form) {
    form.dispatchEvent(new CustomEvent('htmx:abort', { bubbles: true, detail: { elt: form } }));
  }

  function resetNotifyForm(dialog) {
    const form = dialog.querySelector('[data-interest-form]');
    if (!form) return;

    abortInterestRequest(form);
    form.reset();
    form.removeAttribute('aria-busy');
    form.querySelector('.form-feedback')?.replaceChildren();
    form.querySelectorAll('[data-disabled-by-htmx]').forEach((element) => {
      element.removeAttribute('disabled');
      element.removeAttribute('data-disabled-by-htmx');
    });
  }

  function openNotifyDialog(trigger) {
    const dialog = document.querySelector('[data-notify-dialog]');
    if (!(dialog instanceof HTMLDialogElement) || dialog.open) return;

    const mobileMenu = trigger.closest('details[data-mobile-menu]');
    dialogOpener = mobileMenu?.querySelector(':scope > summary') || trigger;
    closeMobileMenus();
    resetNotifyForm(dialog);
    document.documentElement.classList.add('modal-open');
    dialog.showModal();
  }

  function closeNotifyDialog() {
    const dialog = document.querySelector('[data-notify-dialog]');
    if (!(dialog instanceof HTMLDialogElement) || !dialog.open) return;
    const form = dialog.querySelector('[data-interest-form]');
    if (form instanceof HTMLFormElement) abortInterestRequest(form);
    dialog.close();
  }

  function handleDialogClose() {
    document.documentElement.classList.remove('modal-open');
    if (dialogOpener instanceof HTMLElement && dialogOpener.isConnected) dialogOpener.focus();
    dialogOpener = undefined;
  }

  function handleBeforeRequest() {
    ensureHtmxHistoryBridge();
  }

  function handleBeforeSwap() {
    ensureHtmxHistoryBridge();
  }

  function handleAfterSwap(event) {
    const detail = event.detail;
    const status = detail?.xhr?.status || 0;

    const feedback = detail?.target;
    if (feedback instanceof Element && feedback.matches('.form-feedback')) {
      const message = feedback.querySelector('[role="status"], [role="alert"]');
      if (message instanceof HTMLElement) {
        if (!message.hasAttribute('tabindex')) message.tabIndex = -1;
        message.focus();
      }
    }

    if (
      (detail?.boosted || detail?.requestConfig?.boosted)
      && detail?.shouldSwap !== false
      && status >= 200
      && status < 400
      && detail.xhr?.responseText
    ) {
      syncRouteHead(detail.xhr.responseText);
    }

    initializeCountUps(document);
    initializeTrailSlideshows(document);
    syncTrailSwitcher();
    revealActiveTrail();
  }

  function handleAfterSettle(event) {
    const detail = event.detail;
    if (!(detail?.boosted || detail?.requestConfig?.boosted)) return;

    const anchor = window.location.hash.slice(1);
    if (anchor) {
      let target;
      try {
        target = document.getElementById(decodeURIComponent(anchor));
      } catch {
        target = document.getElementById(anchor);
      }
      if (target instanceof HTMLElement) {
        focusTemporarily(target);
        target.scrollIntoView({ block: 'start' });
      }
      return;
    }

    document.querySelector('main')?.focus({ preventScroll: true });
    window.scrollTo({ top: 0, behavior: 'auto' });
  }

  function focusTemporarily(element) {
    const existingTabIndex = element.getAttribute('tabindex');
    if (existingTabIndex === null) element.tabIndex = -1;
    element.focus({ preventScroll: true });

    if (existingTabIndex === null) {
      element.addEventListener('blur', () => element.removeAttribute('tabindex'), { once: true });
    }
  }

  function handleHistoryRestore(event) {
    if (event.detail?.serverResponse) syncRouteHead(event.detail.serverResponse);
    initializeCountUps(document);
    initializeTrailSlideshows(document);
    syncTrailSwitcher();
    revealActiveTrail();
    document.querySelector('main')?.focus({ preventScroll: true });
  }

  function handleHistoryRestoreError() {
    window.location.reload();
  }

  function handleInput(event) {
    const target = event.target;
    if (target instanceof HTMLInputElement && target.matches('[data-stage-filter]')) {
      filterStageDirectory(target);
    }
  }

  function handleDocumentClick(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;

    if (target.closest('.mobile-menu nav a, .mobile-menu nav button')) closeMobileMenus();

    const notifyTrigger = target.closest('[data-notify-trigger]');
    if (notifyTrigger instanceof HTMLElement) {
      openNotifyDialog(notifyTrigger);
      return;
    }

    if (target.closest('[data-notify-close]')) {
      closeNotifyDialog();
      return;
    }

    const dialog = target.closest('[data-notify-dialog]');
    if (dialog && target === dialog) {
      closeNotifyDialog();
      return;
    }

    const toggle = target.closest('[data-trail-slide-toggle]');
    const toggleSlideshow = toggle?.closest('[data-trail-slideshow]');
    if (toggle instanceof HTMLButtonElement && toggleSlideshow) {
      const paused = toggleSlideshow.dataset.userPaused !== 'true';
      toggleSlideshow.dataset.userPaused = String(paused);
      syncSlideshowToggle(toggleSlideshow);
      if (paused) stopTrailSlideshow(toggleSlideshow);
      else scheduleTrailSlideshow(toggleSlideshow);
      return;
    }

    const control = target.closest('[data-trail-slide-go]');
    const slideshow = control?.closest('[data-trail-slideshow]');
    if (!control || !slideshow) return;

    setTrailSlide(slideshow, Number(control.dataset.trailSlideGo), true);
    scheduleTrailSlideshow(slideshow);
  }

  function handlePointerOver(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const slideshow = target.closest('[data-trail-slideshow]');
    if (!slideshow || (event.relatedTarget instanceof Node && slideshow.contains(event.relatedTarget))) return;
    stopTrailSlideshow(slideshow);
  }

  function handlePointerOut(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const slideshow = target.closest('[data-trail-slideshow]');
    if (!slideshow || (event.relatedTarget instanceof Node && slideshow.contains(event.relatedTarget))) return;
    scheduleTrailSlideshow(slideshow);
  }

  function handleFocusIn(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const slideshow = target.closest('[data-trail-slideshow]');
    if (slideshow) stopTrailSlideshow(slideshow);
  }

  function handleFocusOut(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;
    const slideshow = target.closest('[data-trail-slideshow]');
    if (!slideshow || (event.relatedTarget instanceof Node && slideshow.contains(event.relatedTarget))) return;
    scheduleTrailSlideshow(slideshow);
  }

  function handleVisibilityChange() {
    document.querySelectorAll('[data-trail-slideshow-ready]').forEach((slideshow) => {
      if (document.hidden) stopTrailSlideshow(slideshow);
      else scheduleTrailSlideshow(slideshow);
    });
  }

  function handleMotionPreferenceChange(event) {
    reduceMotion = event.matches;

    if (reduceMotion) {
      countObserver?.disconnect();
      countObserver = undefined;
      countFrames.forEach((frame, element) => {
        window.cancelAnimationFrame(frame);
        const target = Number(element.dataset.countUp);
        if (Number.isFinite(target)) element.textContent = target.toLocaleString('en-GB');
      });
      countFrames.clear();
      document.querySelectorAll('[data-count-up]').forEach((element) => {
        const target = Number(element.dataset.countUp);
        if (Number.isFinite(target)) element.textContent = target.toLocaleString('en-GB');
      });
    }

    document.querySelectorAll('[data-trail-slideshow-ready]').forEach((slideshow) => {
      syncSlideshowToggle(slideshow);
      if (reduceMotion) stopTrailSlideshow(slideshow);
      else scheduleTrailSlideshow(slideshow);
    });
  }

  function prepareForPotentialNavigation(event) {
    const target = event.target;
    if (!(target instanceof Element)) return;

    const activeTrail = target.closest('.trail-switcher-item[aria-current="true"]');
    if (activeTrail) {
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }

    if (target.closest('a[href]')) ensureHtmxHistoryBridge();
  }

  try {
    window.sessionStorage.removeItem('htmx-history-cache');
  } catch {
    // Live history restoration still works when session storage is unavailable.
  }

  htmx.config.historyCacheSize = 0;
  ensureHtmxHistoryBridge();

  window.__eurotrexHtmxPopState = handlePopState;
  window.addEventListener('pageshow', ensureHtmxHistoryBridge);
  document.addEventListener('click', prepareForPotentialNavigation, true);
  document.addEventListener('input', handleInput);
  document.addEventListener('click', handleDocumentClick);
  document.addEventListener('pointerover', handlePointerOver);
  document.addEventListener('pointerout', handlePointerOut);
  document.addEventListener('focusin', handleFocusIn);
  document.addEventListener('focusout', handleFocusOut);
  document.addEventListener('visibilitychange', handleVisibilityChange);
  document.body.addEventListener('htmx:beforeRequest', handleBeforeRequest);
  document.body.addEventListener('htmx:beforeSwap', handleBeforeSwap);
  document.body.addEventListener('htmx:beforeHistoryUpdate', ensureHtmxHistoryBridge);
  document.body.addEventListener('htmx:afterSwap', handleAfterSwap);
  document.body.addEventListener('htmx:afterSettle', handleAfterSettle);
  document.body.addEventListener('htmx:historyRestore', handleHistoryRestore);
  document.body.addEventListener('htmx:historyCacheMissLoadError', handleHistoryRestoreError);
  motionPreference.addEventListener('change', handleMotionPreferenceChange);

  const notifyDialog = document.querySelector('[data-notify-dialog]');
  notifyDialog?.addEventListener('close', handleDialogClose);

  initializeCountUps(document);
  initializeTrailSlideshows(document);
  syncTrailSwitcher();
  revealActiveTrail();
}

function loadHtmxAndStart() {
  if (window.htmx) {
    startPublicRuntime(window.htmx);
    return;
  }

  const htmxScript = document.createElement('script');
  htmxScript.src = '/vendor/htmx-2.0.10.min.js';
  htmxScript.onload = () => startPublicRuntime(window.htmx);
  htmxScript.onerror = () => console.error('EuroTrex could not load HTMX.');
  document.head.appendChild(htmxScript);
}

function bootPublicRuntime() {
  const startWhenHydrated = () => loadHtmxAndStart();
  if (document.documentElement.dataset.publicReactHydrated === 'true') {
    startWhenHydrated();
  } else {
    document.addEventListener('eurotrex:public-react-hydrated', startWhenHydrated, { once: true });
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootPublicRuntime, { once: true });
} else {
  bootPublicRuntime();
}
