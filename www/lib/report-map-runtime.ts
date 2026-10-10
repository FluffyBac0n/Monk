'use client';
let runtime: Promise<{gl: typeof import('mapbox-gl').default; accessToken: string}> | undefined;
export function preloadReportMap() {
  if (!runtime) {
    runtime = Promise.all([import('mapbox-gl'), fetch('/api/map-config').then(async response => {
      if (!response.ok) throw new Error('Map configuration unavailable');
      const data = await response.json() as {accessToken: string};
      return data.accessToken;
    })]).then(([module, accessToken]) => ({gl: module.default, accessToken})).catch(error => {runtime = undefined; throw error;});
  }
  return runtime;
}
