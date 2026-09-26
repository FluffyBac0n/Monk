import { publicHtmxNavigation } from '@/lib/htmx';

const trailSwitcherNavigation = {
  ...publicHtmxNavigation,
  'hx-swap': 'outerHTML',
} as const;

const trailGuides = [
  { id: 'cyprus-e4', label: 'Cyprus - E4', href: '/trails/cyprus-e4' },
  { id: 'crete-e4', label: 'Crete - E4', href: '/trails/crete-e4', status: 'Coming soon' },
  { id: 'peloponnese-e4', label: 'Peloponnese - E4', href: '/trails/peloponnese-e4', status: 'Coming soon' },
] as const;

export function TrailGuideSwitcher() {
  return (
    <div className="trail-switcher-bar" {...trailSwitcherNavigation}>
      <nav className="section-shell trail-switcher" aria-label="Explore trails">
        <ul className="trail-switcher-list" role="list">
          {trailGuides.map((trail) => (
            <li key={trail.id}>
              <a
                className={`trail-switcher-item${'status' in trail ? ' preview' : ''}`}
                data-trail-id={trail.id}
                href={trail.href}
              >
                <strong>{trail.label}</strong>
                {'status' in trail ? <small>{trail.status}</small> : null}
              </a>
            </li>
          ))}
        </ul>
      </nav>
    </div>
  );
}
