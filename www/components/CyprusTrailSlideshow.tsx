/* eslint-disable @next/next/no-img-element */

const slides = [
  {
    src: '/cyprus-e4-forest-960.webp',
    srcSet: '/cyprus-e4-forest-640.webp 640w, /cyprus-e4-forest-960.webp 960w, /cyprus-e4-forest-1200.webp 1200w',
    alt: 'A narrow walking trail winding through a pine forest in Cyprus',
    label: 'Troodos highlands',
    title: 'Pine paths and mountain air.',
  },
  {
    src: '/cyprus-e4-hermit-960.webp',
    srcSet: '/cyprus-e4-hermit-640.webp 640w, /cyprus-e4-hermit-960.webp 960w, /cyprus-e4-hermit-1280.webp 1280w',
    alt: 'A cliffside rock opening framed by trees above turquoise Mediterranean water in Cyprus',
    label: 'The Hermit',
    title: 'Where stone meets the sea.',
  },
  {
    src: '/cyprus-e4-hidden-beach-960.webp',
    srcSet: '/cyprus-e4-hidden-beach-640.webp 640w, /cyprus-e4-hidden-beach-960.webp 960w, /cyprus-e4-hidden-beach-1280.webp 1280w',
    alt: 'A secluded beach beneath pale coastal cliffs and blue Mediterranean water in Cyprus',
    label: 'Hidden Beach',
    title: 'Cliff paths and quiet coves.',
  },
  {
    src: '/cyprus-e4-sunset-960.webp',
    srcSet: '/cyprus-e4-sunset-640.webp 640w, /cyprus-e4-sunset-960.webp 960w, /cyprus-e4-sunset-1280.webp 1280w',
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
          <img
            {...(index === 0
              ? { src: slide.src, srcSet: slide.srcSet, sizes: '(max-width: 900px) 100vw, 56vw' }
              : {
                  'data-trail-src': slide.src,
                  'data-trail-srcset': slide.srcSet,
                  'data-trail-sizes': '(max-width: 900px) 100vw, 56vw',
                })}
            alt={slide.alt}
            decoding="async"
            fetchPriority={index === 0 ? 'high' : 'auto'}
          />
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
        <button
          type="button"
          className="trail-slideshow-toggle"
          aria-label="Pause slideshow"
          aria-pressed="false"
          data-trail-slide-toggle
        ><span aria-hidden="true">Ⅱ</span></button>
      </div>
      <span className="sr-only" aria-atomic="true" aria-live="polite" data-trail-slide-status />
    </figure>
  );
}
