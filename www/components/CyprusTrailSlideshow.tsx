import Image from 'next/image';

const slides = [
  {
    src: '/cyprus-e4-forest.jpg',
    alt: 'A narrow walking trail winding through a pine forest in Cyprus',
    label: 'Troodos highlands',
    title: 'Pine paths and mountain air.',
  },
  {
    src: '/cyprus-e4-hermit.webp',
    alt: 'A cliffside rock opening framed by trees above turquoise Mediterranean water in Cyprus',
    label: 'The Hermit',
    title: 'Where stone meets the sea.',
  },
  {
    src: '/cyprus-e4-hidden-beach.webp',
    alt: 'A secluded beach beneath pale coastal cliffs and blue Mediterranean water in Cyprus',
    label: 'Hidden Beach',
    title: 'Cliff paths and quiet coves.',
  },
] as const;

function ArrowIcon({ direction }: { direction: 'previous' | 'next' }) {
  return (
    <svg aria-hidden="true" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <path d={direction === 'previous' ? 'm12.5 4.5-5.5 5.5 5.5 5.5' : 'm7.5 4.5 5.5 5.5-5.5 5.5'} />
    </svg>
  );
}

export function CyprusTrailSlideshow() {
  return (
    <figure
      className="trail-guide-cover trail-guide-slideshow"
      data-active-slide="0"
      data-trail-slideshow
      aria-label="Cyprus E4 landscapes"
      aria-roledescription="carousel"
      role="region"
    >
      {slides.map((slide, index) => (
        <div
          aria-hidden={index !== 0}
          aria-label={`${index + 1} of ${slides.length}: ${slide.label}`}
          aria-roledescription="slide"
          className={`trail-guide-slide${index === 0 ? ' is-active' : ''}`}
          data-trail-slide-label={`${slide.label} — ${slide.title}`}
          data-trail-slide-panel
          key={slide.src}
          role="group"
        >
          <Image src={slide.src} alt={slide.alt} fill priority={index === 0} sizes="(max-width: 900px) 100vw, 56vw" />
          <div className="trail-guide-cover-shade" aria-hidden="true" />
          <div className="trail-guide-slide-caption"><small>{slide.label}</small><strong>{slide.title}</strong></div>
        </div>
      ))}

      <span className="trail-guide-cover-mark">E4 · Cyprus</span>

      <div className="trail-slideshow-controls" aria-label="Choose landscape" role="group">
        <button type="button" aria-label="Previous image" data-trail-slide-previous><ArrowIcon direction="previous" /></button>
        <div className="trail-slideshow-dots">
          {slides.map((slide, index) => (
            <button
              type="button"
              aria-current={index === 0 ? 'true' : undefined}
              aria-label={`Show image ${index + 1}: ${slide.label}`}
              data-trail-slide-go={index}
              key={slide.src}
            ><span /></button>
          ))}
        </div>
        <button type="button" aria-label="Next image" data-trail-slide-next><ArrowIcon direction="next" /></button>
      </div>
      <span className="sr-only" aria-live="polite" data-trail-slide-status>Image 1 of {slides.length}: {slides[0].label} — {slides[0].title}</span>
    </figure>
  );
}
