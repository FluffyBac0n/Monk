'use client';
import { useEffect, useState } from 'react';
import type { User } from 'firebase/auth';

type Story = {
  id: string;
  title: string;
  publicName: string;
  body: string;
  status: string;
  createdAt: string;
  consentAt: string;
};
export function StoryModeration({ user }: { user: User }) {
  const [stories, setStories] = useState<Story[]>([]),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(true),
    [revision, setRevision] = useState(0),
    [busy, setBusy] = useState('');
  useEffect(() => {
    let active = true;
    async function load() {
      try {
        const token = await user.getIdToken();
        const response = await fetch('/api/stories', {
          headers: { Authorization: `Bearer ${token}` },
        });
        const result = (await response.json()) as {
          error?: string;
          stories: Story[];
        };
        if (!response.ok)
          throw new Error(result.error || 'Stories could not be loaded.');
        if (active) {
          setStories(result.stories);
          setError('');
        }
      } catch (error) {
        if (active)
          setError(
            error instanceof Error
              ? error.message
              : 'Stories could not be loaded.'
          );
      } finally {
        if (active) setLoading(false);
      }
    }
    void load();
    return () => {
      active = false;
    };
  }, [user, revision]);
  async function review(id: string, action: 'approve' | 'reject') {
    setBusy(id);
    setError('');
    try {
      const token = await user.getIdToken();
      const response = await fetch('/api/stories', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ id, action }),
      });
      const result = (await response.json()) as { error?: string };
      if (!response.ok)
        throw new Error(result.error || 'Review could not be saved.');
      setRevision((value) => value + 1);
    } catch (error) {
      setError(
        error instanceof Error ? error.message : 'Review could not be saved.'
      );
    } finally {
      setBusy('');
    }
  }
  return (
    <section>
      <div className="panel-heading">
        <div>
          <p className="eyebrow">GET INSPIRED</p>
          <h2>Trail story review</h2>
          <p>
            Only approved contributions with publication permission appear
            publicly. Rejecting a published story removes it from Get Inspired.
          </p>
        </div>
        <button
          className="button button-secondary"
          onClick={() => setRevision((value) => value + 1)}
        >
          Refresh
        </button>
      </div>
      {error && (
        <p className="notice error" role="alert">
          {error}
        </p>
      )}
      {loading ? (
        <p role="status">Loading stories…</p>
      ) : (
        <div className="story-grid">
          {!stories.length && <p>No stories have been submitted yet.</p>}
          {stories.map((story) => (
            <article key={story.id}>
              <p className="eyebrow">
                {story.status === 'new' ? 'Awaiting review' : story.status}
              </p>
              <h3>{story.title}</h3>
              <p className="story-body">{story.body}</p>
              <p>
                Public name: <strong>{story.publicName}</strong>
              </p>
              <small>
                Publication permission recorded{' '}
                {new Date(story.consentAt).toLocaleDateString()}
              </small>
              <div className="editorial-actions">
                {story.status !== 'approved' && (
                  <button
                    className="button button-primary"
                    disabled={Boolean(busy)}
                    onClick={() => void review(story.id, 'approve')}
                  >
                    Approve &amp; publish
                  </button>
                )}
                {story.status !== 'rejected' && (
                  <button
                    className="button button-secondary"
                    disabled={Boolean(busy)}
                    onClick={() => void review(story.id, 'reject')}
                  >
                    {story.status === 'approved'
                      ? 'Remove from publication'
                      : 'Reject'}
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}
