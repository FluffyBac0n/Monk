import Image from 'next/image';
import type { Metadata } from 'next';
import { EditorialPage } from '@/components/EditorialPage';
import { InterestForm } from '@/components/InterestForm';
import { websiteCopy } from '@/lib/website-copy';
import { publishedStories, type PublicStory } from '@/lib/trail-stories';

export const metadata: Metadata = {
  title: 'Get Inspired',
  description: websiteCopy.inspiration.introduction,
  alternates: { canonical: '/get-inspired' },
};
const copy = websiteCopy.inspiration;
const photos = [
  [
    '/cyprus-e4-forest-1200.webp',
    'A forest path',
    'A quiet stretch of forest along the trail',
  ],
  [
    '/zapalo-coast-hero-1280.webp',
    'Where the path meets the sea',
    'The cliffs and turquoise water at Zapalo Bay',
  ],
  [
    '/cyprus-e4-sunset-1280.webp',
    'One step at a time',
    'Evening light across the Cyprus landscape',
  ],
];

export default async function Inspiration() {
  let stories: PublicStory[] = [];
  let storiesAvailable = true;
  try {
    stories = await publishedStories();
  } catch {
    storiesAvailable = false;
  }
  return (
    <EditorialPage
      eyebrow="Get Inspired"
      title="Understanding Your Journey"
      introduction={copy.introduction}
      image="/cyprus-e4-sunset-1280.webp"
      imageAlt="The Cyprus landscape in warm evening light"
    >
      <section className="section-shell inspiration-introduction">
        <p>{copy.questions}</p>
        <h2>{copy.closing}</h2>
      </section>
      <section className="section-shell">
        <h2 className="section-title">Inspiring Quotes</h2>
        <div className="quote-grid">
          {copy.quotes.map(([quote, author]) => (
            <figure key={quote}>
              <blockquote>“{quote}”</blockquote>
              {author && <figcaption>— {author}</figcaption>}
            </figure>
          ))}
        </div>
      </section>
      <section className="section-shell inspiration-stories" id="stories">
        <p className="eyebrow">Inspiring Stories</p>
        <h2>
          Every journey begins
          <br />
          with a reason.
        </h2>
        {!storiesAvailable ? (
          <p className="trail-data-message">
            Stories could not be loaded. Please try again shortly.
          </p>
        ) : stories.length ? (
          <div className="story-grid">
            {stories.map((story) => (
              <article key={story.id}>
                <h3>{story.title}</h3>
                <p className="story-body">{story.body}</p>
                <p className="story-byline">Shared by {story.publicName}</p>
              </article>
            ))}
          </div>
        ) : (
          <p>
            Be the first to share a story from your journey. Reviewed
            contributions will appear here.
          </p>
        )}
        <a className="button button-secondary cta-button" href="#share-story">
          Submit Your Trail Story
        </a>
      </section>
      <section className="section-shell">
        <h2 className="section-title">Inspiring E-Photos</h2>
        <div className="inspiration-photos">
          {photos.map(([src, title, alt]) => (
            <figure key={src}>
              <Image
                src={src}
                alt={alt}
                width={960}
                height={640}
                sizes="(max-width: 760px) 100vw, 33vw"
              />
              <figcaption>{title}</figcaption>
            </figure>
          ))}
        </div>
      </section>
      <section
        className="section-shell form-page-grid programme-enquiry"
        id="share-story"
      >
        <div>
          <p className="eyebrow">What is your motivation on the trail?</p>
          <h2>
            Your story could be
            <br />
            someone’s first step.
          </h2>
          <p>{copy.submission}</p>
        </div>
        <div className="enquiry-panel">
          <InterestForm kind="involved" defaultInterest="story" story />
        </div>
      </section>
    </EditorialPage>
  );
}
