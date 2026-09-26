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
  {
    src: '/cyprus-e4-sunset.webp',
    alt: 'The sun setting over the Mediterranean beside the pale coastal cliffs of Cyprus',
    label: 'Zapalo sunset',
    title: 'The coast, washed in gold.',
  },
] as const;

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
      </div>
      <span className="sr-only" aria-atomic="true" aria-live="polite" data-trail-slide-status />
    </figure>
  );
}
