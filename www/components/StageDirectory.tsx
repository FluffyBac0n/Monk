import type { CyprusE4Stage } from '@/lib/cyprus-e4-data';

export function StageDirectory({ stages }: { stages: CyprusE4Stage[] }) {
  return (
    <section className="stage-directory" aria-labelledby="stage-directory-title">
      <div className="directory-heading">
        <div><p className="eyebrow">Points along the trail</p><h2 id="stage-directory-title">Every stage point, in trail order.</h2></div>
        <label className="stage-search">Find a place<input type="search" data-stage-filter placeholder="Try Troodos or Pafos" /></label>
      </div>
      <p className="directory-count" data-stage-count role="status">Showing {stages.length} of {stages.length} stage points</p>
      <ol className="stage-list" role="list">
        {stages.map((stage, index) => (
          <li key={stage.id} data-stage-search={`${stage.sequence} ${stage.name}`.toLowerCase()}>
            <a href={`/trails/cyprus-e4/stages/${stage.id}`}>
              <span className="stage-order">{String(index + 1).padStart(3, '0')}</span>
              <span className="stage-name"><strong>{stage.name}</strong><small>{stage.accumulatedDistanceKm?.toFixed(1) ?? '—'} km from Pafos</small></span>
              <span className="stage-distance">{index === 0 ? 'Start' : `${stage.segmentLengthKm?.toFixed(1) ?? '—'} km`}<b aria-hidden="true">→</b></span>
            </a>
          </li>
        ))}
      </ol>
      <p className="empty-search" data-stage-empty hidden>No stage point matches “<span data-stage-query />”. Try another place name.</p>
    </section>
  );
}
