import { database, ensureInterestSchema } from './db';

export type PublicStory = {
  id: string;
  title: string;
  publicName: string;
  body: string;
};
export async function publishedStories(): Promise<PublicStory[]> {
  await ensureInterestSchema();
  const result = await database()
    .prepare(
      `SELECT s.id, p.title, p.public_name AS publicName, s.message AS body
    FROM interest_submissions s JOIN story_publication_permissions p ON p.submission_id=s.id
    WHERE s.kind='involved' AND s.interest='story' AND s.status='approved' AND p.publication_consent=1
    ORDER BY p.reviewed_at DESC LIMIT 12`
    )
    .all<PublicStory>();
  return result.results;
}
