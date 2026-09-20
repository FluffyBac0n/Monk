export const publicHtmxNavigation = {
  'hx-boost': 'true',
  'hx-target': 'main',
  'hx-select': 'main',
  'hx-swap': 'outerHTML transition:true',
  'hx-push-url': 'true',
} as const;

export const disableHtmxNavigation = {
  'hx-boost': 'false',
} as const;

