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

export function inPlaceTrailSection(
  id: 'planner' | 'accommodations',
  url = '/trails/cyprus-e4'
) {
  return {
    'data-trail-section-update': id,
    'hx-get': url,
    'hx-target': `#${id}`,
    'hx-select': `#${id}`,
    'hx-swap': 'outerHTML show:none',
    'hx-boost': 'false',
    'hx-push-url': 'true',
  } as const;
}
