/** Display names only: stable route IDs and stored records remain unchanged. */
export function trailDisplayName(id: string, fallback = 'Trail') {
  const names: Record<string, string> = {
    'cyprus-e4': 'Cyprus-E4',
    'crete-e4': 'Crete-E4',
    'peloponnese-e4': 'Peloponnese-E4',
  };
  return names[id] || fallback;
}
