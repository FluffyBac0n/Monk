import Image from 'next/image';
import { PublicContent } from '@/components/PublicContent';
import { PublicFooter } from '@/components/PublicFooter';
import { PublicHeader } from '@/components/PublicHeader';
import { publicHtmxNavigation } from '@/lib/htmx';

type FutureTrailPreviewProps = {
  activeTrail: 'crete-e4' | 'peloponnese-e4';
  trailName: string;
  title: string;
  introduction: string;
  imageSrc: string;
  imageAlt: string;
};

export function FutureTrailPreview({
  activeTrail,
  trailName,
  title,
  introduction,
  imageSrc,
  imageAlt,
}: FutureTrailPreviewProps) {
  const headingId = `${activeTrail}-preview-title`;

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <PublicHeader />
      <PublicContent>
        <main
          id="main-content"
          className={`content-page future-trail-page future-trail-page--${activeTrail}`}
          data-trail-guide={activeTrail}
          tabIndex={-1}
          {...publicHtmxNavigation}
        >
          <section className="future-trail-hero" aria-labelledby={headingId}>
            <div className="section-shell future-trail-hero-grid">
              <div className="future-trail-copy">
                <p className="eyebrow">Coming soon · Trail guide preview</p>
                <h1 id={headingId}>{title}</h1>
                <p className="future-trail-lead">{introduction}</p>

                <div className="future-trail-status" role="note" aria-label={`${trailName} guide status`}>
                  <span aria-hidden="true" />
                  <div>
                    <strong>Verification in progress</strong>
                    <p>Route data, stage points, services and current trail conditions are being checked before this guide goes live.</p>
                  </div>
                </div>

                <div className="future-trail-actions">
                  <a className="button button-primary fill-link" href="/trails/cyprus-e4">
                    <span>Explore the live Cyprus E4 guide</span>
                  </a>
                  <a className="guide-inline-link" href="/#app-updates">
                    Get trail updates <span aria-hidden="true">→</span>
                  </a>
                </div>
              </div>

              <figure className="future-trail-image">
                <Image
                  src={imageSrc}
                  alt={imageAlt}
                  fill
                  priority
                  sizes="(max-width: 900px) 100vw, 56vw"
                />
                <div className="future-trail-image-shade" aria-hidden="true" />
                <figcaption>
                  <small>Visual placeholder</small>
                  <strong>{trailName}</strong>
                  <span>Not verified trail imagery</span>
                </figcaption>
              </figure>
            </div>
          </section>

          <section className="future-trail-preparing" aria-labelledby={`${activeTrail}-preparing-title`}>
            <div className="section-shell future-trail-preparing-inner">
              <div className="future-trail-preparing-heading">
                <p className="eyebrow">Before we publish</p>
                <h2 id={`${activeTrail}-preparing-title`}>A useful guide begins with verified details.</h2>
              </div>
              <ul className="future-trail-checklist" role="list">
                <li><strong>Route and stages</strong><span>The line, access points and walking sections.</span></li>
                <li><strong>Services and access</strong><span>Places to stay, resupply and reach the trail.</span></li>
                <li><strong>Conditions</strong><span>Terrain notes, safety context and verification dates.</span></li>
              </ul>
            </div>
          </section>
        </main>
      </PublicContent>
      <PublicFooter />
    </>
  );
}
