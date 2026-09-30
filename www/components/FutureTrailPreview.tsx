import Image from 'next/image';
import { NotifyButton } from '@/components/NotifyDialog';
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
  const photo = activeTrail === 'crete-e4'
    ? { place: 'Samaria Gorge, Crete', author: 'Robert Linsdell', source: 'https://commons.wikimedia.org/wiki/File:Samaria_Gorge,_Crete_(150857)_(9450576425).jpg', license: '2.0' }
    : { place: 'Taygetos mountains, Peloponnese', author: 'Herbert Ortner', source: 'https://commons.wikimedia.org/wiki/File:Taygetos_Ilias_1.jpg', license: '3.0' };

  return (
    <>
      <a className="skip-link" href="#main-content">Skip to content</a>
      <PublicHeader activeTrail={activeTrail} />
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
                    <strong>Planned guide · Not yet available</strong>
                    <p>Route details and services will be published after review. There is no confirmed release date yet; this preview is not a navigation guide.</p>
                  </div>
                </div>

                <div className="future-trail-actions">
                  <a className="button button-primary fill-link" href="/trails/cyprus-e4">
                    <span>Explore the live Cyprus-E4 guide</span>
                  </a>
                  <NotifyButton className="button button-secondary" trail={activeTrail}>Notify me about {trailName}</NotifyButton>
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
                  <small>Destination landscape · Not a verified route view</small>
                  <strong>{photo.place}</strong>
                  <span>Photo: <a href={photo.source}>{photo.author}</a> · <a href={`https://creativecommons.org/licenses/by/${photo.license}/`}>CC BY {photo.license}</a> · Resized and cropped for display</span>
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
