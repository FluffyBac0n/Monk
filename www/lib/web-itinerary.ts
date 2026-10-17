import type { CyprusE4Stage } from './cyprus-e4-data';
import type { PublicLodging } from './public-trail-data';

export type ItineraryOptions = {
  start: string;
  end: string;
  days?: number;
  maxKm: number;
  camping: boolean;
};
export type WalkingDay = {
  number: number;
  start: CyprusE4Stage;
  end: CyprusE4Stage;
  points: CyprusE4Stage[];
  distanceKm: number;
  ascentM: number | null;
  descentM: number | null;
  lodgings: PublicLodging[];
  camping: boolean;
};
export type ItineraryResult = {
  days: WalkingDay[];
  error?: string;
  minimumDays?: number;
  distanceKm: number;
};

/** Split the database's ordered reference points into balanced, feasible walking days. */
export function buildItinerary(
  stages: CyprusE4Stage[],
  lodgings: PublicLodging[],
  options: ItineraryOptions
): ItineraryResult {
  const fail = (
    error: string,
    distanceKm = 0,
    minimumDays?: number
  ): ItineraryResult => ({ days: [], error, distanceKm, minimumDays });
  if (
    !Number.isFinite(options.maxKm) ||
    options.maxKm < 5 ||
    options.maxKm > 80 ||
    (options.days !== undefined &&
      (!Number.isInteger(options.days) ||
        options.days < 1 ||
        options.days > 90))
  )
    return fail(
      'Choose a daily limit from 5 to 80 km and, optionally, 1–90 walking days.'
    );
  const start = stages.findIndex((point) => point.id === options.start),
    end = stages.findIndex((point) => point.id === options.end);
  if (start < 0 || end < 0 || start === end)
    return fail('Choose two different trail points for the start and finish.');
  const reverse = end < start;
  const path = stages.slice(Math.min(start, end), Math.max(start, end) + 1);
  if (reverse) path.reverse();
  if (
    path.some(
      (point) =>
        point.accumulatedDistanceKm === null ||
        !Number.isFinite(point.accumulatedDistanceKm)
    )
  )
    return fail(
      'Distance data is missing for part of this route. Try another section.'
    );
  const distance = (a: number, b: number) =>
    Math.abs(path[b].accumulatedDistanceKm! - path[a].accumulatedDistanceKm!);
  const total = distance(0, path.length - 1);
  const stays = new Map<string, PublicLodging[]>();
  for (const lodging of lodgings.filter(
    (stay) => stay.name?.trim() || (stay.type && stay.location)
  )) {
    const group = stays.get(lodging.stageId) || [];
    group.push(lodging);
    stays.set(lodging.stageId, group);
  }
  const overnight = (index: number) =>
    index === path.length - 1 ||
    Boolean(path[index].services.lodging) ||
    stays.has(path[index].id) ||
    (options.camping && Boolean(path[index].services.tent));
  const minimum = Array<number>(path.length).fill(Infinity);
  minimum[0] = 0;
  for (let b = 1; b < path.length; b++)
    if (overnight(b)) {
      for (let a = 0; a < b; a++)
        if (distance(a, b) > 0 && distance(a, b) <= options.maxKm + 1e-8)
          minimum[b] = Math.min(minimum[b], minimum[a] + 1);
    }
  const minimumDays = minimum.at(-1)!;
  if (!Number.isFinite(minimumDays))
    return fail(
      'No itinerary fits this daily limit and the recorded overnight stops. Increase the limit, choose a shorter section or allow recorded camping stops.',
      total
    );
  const days = options.days ?? minimumDays;
  if (days < minimumDays)
    return fail(
      `This section needs at least ${minimumDays} walking days with your daily limit and overnight choices.`,
      total,
      minimumDays
    );
  const score = Array.from({ length: days + 1 }, () =>
    Array<number>(path.length).fill(Infinity)
  );
  const previous = Array.from({ length: days + 1 }, () =>
    Array<number>(path.length).fill(-1)
  );
  score[0][0] = 0;
  const ideal = total / days;
  for (let day = 1; day <= days; day++)
    for (let b = 1; b < path.length; b++)
      if (overnight(b)) {
        for (let a = 0; a < b; a++) {
          const km = distance(a, b);
          if (
            km <= 0 ||
            km > options.maxKm + 1e-8 ||
            !Number.isFinite(score[day - 1][a])
          )
            continue;
          const value = score[day - 1][a] + (km - ideal) ** 2;
          if (value < score[day][b]) {
            score[day][b] = value;
            previous[day][b] = a;
          }
        }
      }
  if (!Number.isFinite(score[days][path.length - 1]))
    return fail(
      'The requested number of days cannot be formed from these recorded overnight stops. Reduce the number of days or change the section.',
      total,
      minimumDays
    );
  const boundaries: number[] = [path.length - 1];
  for (let day = days; day > 0; day--)
    boundaries.push(previous[day][boundaries.at(-1)!]);
  boundaries.reverse();
  const result: WalkingDay[] = boundaries.slice(1).map((finish, index) => {
    const begin = boundaries[index];
    // Canonical incoming metrics belong to the arriving point; reverse shifts and swaps them.
    const metricPoints = reverse
      ? path.slice(begin, finish)
      : path.slice(begin + 1, finish + 1);
    const sum = (key: 'elevationUpM' | 'elevationDownM') =>
      metricPoints.every(
        (point) => point[key] !== null && Number.isFinite(point[key])
      )
        ? metricPoints.reduce((total, point) => total + point[key]!, 0)
        : null;
    const endPoint = path[finish];
    return {
      number: index + 1,
      start: path[begin],
      end: endPoint,
      points: path.slice(begin, finish + 1),
      distanceKm: distance(begin, finish),
      ascentM: sum(reverse ? 'elevationDownM' : 'elevationUpM'),
      descentM: sum(reverse ? 'elevationUpM' : 'elevationDownM'),
      lodgings: stays.get(endPoint.id) || [],
      camping: options.camping && Boolean(endPoint.services.tent),
    };
  });
  return { days: result, distanceKm: total, minimumDays };
}
