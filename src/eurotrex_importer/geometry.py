from __future__ import annotations

from dataclasses import dataclass
from math import asin, cos, radians, sin, sqrt


EARTH_RADIUS_KM = 6371.0088


@dataclass(frozen=True)
class PolylineMatch:
    distanceKm: float
    firstSegmentIndex: int
    secondSegmentIndex: int
    firstFraction: float
    secondFraction: float
    firstLocation: tuple[float, float]
    secondLocation: tuple[float, float]
    firstDistanceKm: float
    secondDistanceKm: float


def haversine_distance_km(
    first: tuple[float, float],
    second: tuple[float, float],
) -> float:
    lat1, lng1 = first
    lat2, lng2 = second
    delta_lat = radians(lat2 - lat1)
    delta_lng = radians(lng2 - lng1)
    a = sin(delta_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(delta_lng / 2) ** 2
    return EARTH_RADIUS_KM * 2 * asin(sqrt(min(1.0, a)))


def cumulative_distances_km(points: list[tuple[float, float]]) -> list[float]:
    if not points:
        return []
    distances = [0.0]
    for index in range(1, len(points)):
        distances.append(distances[-1] + haversine_distance_km(points[index - 1], points[index]))
    return distances


def closest_polyline_match(
    first_points: list[tuple[float, float]],
    second_points: list[tuple[float, float]],
    *,
    first_distances_km: list[float] | None = None,
    second_distances_km: list[float] | None = None,
) -> PolylineMatch:
    if not first_points or not second_points:
        raise ValueError("Both polylines must contain at least one point.")

    first_distances = first_distances_km or cumulative_distances_km(first_points)
    second_distances = second_distances_km or cumulative_distances_km(second_points)
    if len(first_distances) != len(first_points) or len(second_distances) != len(second_points):
        raise ValueError("Polyline point and distance counts must match.")

    latitude_reference = sum(point[0] for point in first_points + second_points) / (
        len(first_points) + len(second_points)
    )
    longitude_scale = cos(radians(latitude_reference))

    def project(point: tuple[float, float]) -> tuple[float, float]:
        return (
            EARTH_RADIUS_KM * radians(point[1]) * longitude_scale,
            EARTH_RADIUS_KM * radians(point[0]),
        )

    first_projected = [project(point) for point in first_points]
    second_projected = [project(point) for point in second_points]

    first_segments = _segments(first_projected)
    second_segments = _segments(second_projected)
    best: tuple[float, int, int, float, float] | None = None

    for first_index, first_start, first_end in first_segments:
        first_min_x = min(first_start[0], first_end[0])
        first_max_x = max(first_start[0], first_end[0])
        first_min_y = min(first_start[1], first_end[1])
        first_max_y = max(first_start[1], first_end[1])
        for second_index, second_start, second_end in second_segments:
            if best is not None:
                bbox_distance_sq = _bounding_box_distance_sq(
                    first_min_x,
                    first_max_x,
                    first_min_y,
                    first_max_y,
                    min(second_start[0], second_end[0]),
                    max(second_start[0], second_end[0]),
                    min(second_start[1], second_end[1]),
                    max(second_start[1], second_end[1]),
                )
                if bbox_distance_sq >= best[0]:
                    continue

            distance_sq, first_fraction, second_fraction = _closest_segment_points(
                first_start,
                first_end,
                second_start,
                second_end,
            )
            if best is None or distance_sq < best[0]:
                best = (
                    distance_sq,
                    first_index,
                    second_index,
                    first_fraction,
                    second_fraction,
                )

    if best is None:
        raise ValueError("Unable to match the supplied polylines.")

    _, first_index, second_index, first_fraction, second_fraction = best
    first_location = _interpolate_location(
        first_points[first_index],
        first_points[min(first_index + 1, len(first_points) - 1)],
        first_fraction,
    )
    second_location = _interpolate_location(
        second_points[second_index],
        second_points[min(second_index + 1, len(second_points) - 1)],
        second_fraction,
    )
    return PolylineMatch(
        distanceKm=haversine_distance_km(first_location, second_location),
        firstSegmentIndex=first_index,
        secondSegmentIndex=second_index,
        firstFraction=first_fraction,
        secondFraction=second_fraction,
        firstLocation=first_location,
        secondLocation=second_location,
        firstDistanceKm=_interpolate_distance(first_distances, first_index, first_fraction),
        secondDistanceKm=_interpolate_distance(second_distances, second_index, second_fraction),
    )


def point_distances_to_polyline_km(
    points: list[tuple[float, float]],
    polyline: list[tuple[float, float]],
) -> list[float]:
    """Return each point's shortest distance to a polyline in kilometres."""

    if not points or not polyline:
        return []
    latitude_reference = sum(point[0] for point in points + polyline) / (
        len(points) + len(polyline)
    )
    longitude_scale = cos(radians(latitude_reference))

    def project(point: tuple[float, float]) -> tuple[float, float]:
        return (
            EARTH_RADIUS_KM * radians(point[1]) * longitude_scale,
            EARTH_RADIUS_KM * radians(point[0]),
        )

    projected_points = [project(point) for point in points]
    segments = _segments([project(point) for point in polyline])
    distances: list[float] = []
    for point in projected_points:
        best_distance_sq = min(
            _point_to_segment(point, start, end)[0] for _, start, end in segments
        )
        distances.append(sqrt(max(0.0, best_distance_sq)))
    return distances


def _segments(
    points: list[tuple[float, float]],
) -> list[tuple[int, tuple[float, float], tuple[float, float]]]:
    if len(points) == 1:
        return [(0, points[0], points[0])]
    return [(index, points[index], points[index + 1]) for index in range(len(points) - 1)]


def _closest_segment_points(
    first_start: tuple[float, float],
    first_end: tuple[float, float],
    second_start: tuple[float, float],
    second_end: tuple[float, float],
) -> tuple[float, float, float]:
    intersection = _segment_intersection(
        first_start,
        first_end,
        second_start,
        second_end,
    )
    if intersection is not None:
        return 0.0, intersection[0], intersection[1]

    candidates: list[tuple[float, float, float]] = []
    distance_sq, second_fraction = _point_to_segment(first_start, second_start, second_end)
    candidates.append((distance_sq, 0.0, second_fraction))
    distance_sq, second_fraction = _point_to_segment(first_end, second_start, second_end)
    candidates.append((distance_sq, 1.0, second_fraction))
    distance_sq, first_fraction = _point_to_segment(second_start, first_start, first_end)
    candidates.append((distance_sq, first_fraction, 0.0))
    distance_sq, first_fraction = _point_to_segment(second_end, first_start, first_end)
    candidates.append((distance_sq, first_fraction, 1.0))
    return min(candidates, key=lambda candidate: candidate[0])


def _segment_intersection(
    first_start: tuple[float, float],
    first_end: tuple[float, float],
    second_start: tuple[float, float],
    second_end: tuple[float, float],
) -> tuple[float, float] | None:
    first_delta = (first_end[0] - first_start[0], first_end[1] - first_start[1])
    second_delta = (second_end[0] - second_start[0], second_end[1] - second_start[1])
    denominator = _cross(first_delta, second_delta)
    if abs(denominator) < 1e-12:
        return None

    offset = (second_start[0] - first_start[0], second_start[1] - first_start[1])
    first_fraction = _cross(offset, second_delta) / denominator
    second_fraction = _cross(offset, first_delta) / denominator
    if -1e-12 <= first_fraction <= 1 + 1e-12 and -1e-12 <= second_fraction <= 1 + 1e-12:
        return _clamp(first_fraction), _clamp(second_fraction)
    return None


def _point_to_segment(
    point: tuple[float, float],
    start: tuple[float, float],
    end: tuple[float, float],
) -> tuple[float, float]:
    delta_x = end[0] - start[0]
    delta_y = end[1] - start[1]
    length_sq = delta_x * delta_x + delta_y * delta_y
    if length_sq <= 1e-18:
        return (point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2, 0.0
    fraction = _clamp(
        ((point[0] - start[0]) * delta_x + (point[1] - start[1]) * delta_y) / length_sq
    )
    nearest_x = start[0] + fraction * delta_x
    nearest_y = start[1] + fraction * delta_y
    return (point[0] - nearest_x) ** 2 + (point[1] - nearest_y) ** 2, fraction


def _bounding_box_distance_sq(
    first_min_x: float,
    first_max_x: float,
    first_min_y: float,
    first_max_y: float,
    second_min_x: float,
    second_max_x: float,
    second_min_y: float,
    second_max_y: float,
) -> float:
    delta_x = max(first_min_x - second_max_x, second_min_x - first_max_x, 0.0)
    delta_y = max(first_min_y - second_max_y, second_min_y - first_max_y, 0.0)
    return delta_x * delta_x + delta_y * delta_y


def _interpolate_location(
    start: tuple[float, float],
    end: tuple[float, float],
    fraction: float,
) -> tuple[float, float]:
    return (
        start[0] + (end[0] - start[0]) * fraction,
        start[1] + (end[1] - start[1]) * fraction,
    )


def _interpolate_distance(distances: list[float], index: int, fraction: float) -> float:
    end_index = min(index + 1, len(distances) - 1)
    return distances[index] + (distances[end_index] - distances[index]) * fraction


def _cross(first: tuple[float, float], second: tuple[float, float]) -> float:
    return first[0] * second[1] - first[1] * second[0]


def _clamp(value: float) -> float:
    return min(1.0, max(0.0, value))
