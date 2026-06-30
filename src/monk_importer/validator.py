from __future__ import annotations

import json
from collections import Counter
from pathlib import Path
from typing import Any

from .models import ImportPayload, RouteChunk


def build_validation_report(payload: ImportPayload) -> dict[str, Any]:
    stage_ids = [stage.id for stage in payload.stages]
    lodging_ids = [lodging.id for lodging in payload.lodgings]
    route_marker_ids = [marker.id for marker in payload.routeMarkers]
    known_stage_ids = set(stage_ids)

    stage_duplicate_ids = duplicates(stage_ids)
    lodging_duplicate_ids = duplicates(lodging_ids)
    marker_duplicate_ids = duplicates(route_marker_ids)

    lodgings_missing_stage = [
        lodging.id
        for lodging in payload.lodgings
        if lodging.stageId is None or lodging.stageId not in known_stage_ids
    ]
    lodgings_missing_name = [lodging.id for lodging in payload.lodgings if not lodging.name]
    lodgings_with_location = [lodging.id for lodging in payload.lodgings if lodging.location is not None]
    lodgings_with_price = [lodging.id for lodging in payload.lodgings if lodging.priceMinEur is not None]

    services_summary = {
        "lodging": sum(stage.services.lodging for stage in payload.stages),
        "tent": sum(stage.services.tent for stage in payload.stages),
        "food": sum(stage.services.food for stage in payload.stages),
        "grocery": sum(stage.services.grocery for stage in payload.stages),
        "drinkableWater": sum(stage.services.drinkableWater for stage in payload.stages),
        "toilets": sum(stage.services.toilets for stage in payload.stages),
        "medical": sum(stage.services.medical for stage in payload.stages),
        "pharmacy": sum(stage.services.pharmacy for stage in payload.stages),
        "atm": sum(stage.services.atm for stage in payload.stages),
        "busStop": sum(stage.services.busStop for stage in payload.stages),
    }

    route_points = flatten_route_points(payload.routeChunks)
    distance_issues = monotonic_issues([point[3] for point in route_points])
    reverse_distance_issues = reverse_monotonic_issues([point[4] for point in route_points])
    chunk_issues = route_chunk_issues(payload.routeChunks, payload.routeMetadata.chunkSize)
    marker_stage_issues = [
        marker.id
        for marker in payload.routeMarkers
        if marker.stageId is None or marker.stageId not in known_stage_ids
    ]

    issues = []
    warnings = list(payload.warnings)
    if stage_duplicate_ids:
        issues.append(f"Duplicate stage IDs: {stage_duplicate_ids}")
    if lodging_duplicate_ids:
        issues.append(f"Duplicate lodging IDs: {lodging_duplicate_ids}")
    if marker_duplicate_ids:
        issues.append(f"Duplicate route marker IDs: {marker_duplicate_ids}")
    if lodgings_missing_stage:
        issues.append(f"{len(lodgings_missing_stage)} lodging records do not map to a known stage")
    if marker_stage_issues:
        warnings.append(
            f"{len(marker_stage_issues)} route markers are route labels/waypoints without a stage link"
        )
    if len(route_points) != payload.routeMetadata.pointCount:
        issues.append(
            "Route point count mismatch: "
            f"metadata={payload.routeMetadata.pointCount}, chunks={len(route_points)}"
        )
    if distance_issues:
        issues.append(f"Route accumulated distance is not increasing at {len(distance_issues)} points")
    if reverse_distance_issues:
        issues.append(f"Route reverse distance is not decreasing at {len(reverse_distance_issues)} points")
    if chunk_issues:
        issues.extend(chunk_issues)
    if lodgings_missing_name:
        warnings.append(f"{len(lodgings_missing_name)} lodging records have no lodging name")

    return {
        "ok": not issues,
        "issues": issues,
        "warnings": warnings,
        "counts": {
            "stages": len(payload.stages),
            "lodgings": len(payload.lodgings),
            "routePoints": len(route_points),
            "routeChunks": len(payload.routeChunks),
            "routeMarkers": len(payload.routeMarkers),
        },
        "stages": {
            "first": payload.stages[0].model_dump(mode="json") if payload.stages else None,
            "last": payload.stages[-1].model_dump(mode="json") if payload.stages else None,
            "duplicateIds": stage_duplicate_ids,
            "servicesSummary": services_summary,
        },
        "lodgings": {
            "duplicateIds": lodging_duplicate_ids,
            "missingStageCount": len(lodgings_missing_stage),
            "missingNameCount": len(lodgings_missing_name),
            "withLocationCount": len(lodgings_with_location),
            "withPriceCount": len(lodgings_with_price),
            "sample": [lodging.model_dump(mode="json") for lodging in payload.lodgings[:5]],
        },
        "route": {
            "metadata": payload.routeMetadata.model_dump(mode="json"),
            "firstPoint": route_points[0] if route_points else None,
            "lastPoint": route_points[-1] if route_points else None,
            "distanceIssueCount": len(distance_issues),
            "reverseDistanceIssueCount": len(reverse_distance_issues),
            "chunkIssues": chunk_issues,
            "markerStageIssueCount": len(marker_stage_issues),
            "sampleMarkers": [
                marker.model_dump(mode="json") for marker in payload.routeMarkers[:5]
            ],
        },
    }


def write_validation_report(report: dict[str, Any], markdown_path: Path, json_path: Path | None = None) -> None:
    markdown_path.parent.mkdir(parents=True, exist_ok=True)
    markdown_path.write_text(render_markdown_report(report), encoding="utf-8")
    if json_path:
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


def render_markdown_report(report: dict[str, Any]) -> str:
    status = "PASS" if report["ok"] else "FAIL"
    counts = report["counts"]
    stages = report["stages"]
    lodgings = report["lodgings"]
    route = report["route"]
    services = stages["servicesSummary"]
    metadata = route["metadata"]

    lines = [
        "# Monk Import Validation Report",
        "",
        f"Status: **{status}**",
        "",
        "## Counts",
        "",
        f"- Stages: {counts['stages']}",
        f"- Lodgings: {counts['lodgings']}",
        f"- Route points: {counts['routePoints']}",
        f"- Route chunks: {counts['routeChunks']}",
        f"- Route markers: {counts['routeMarkers']}",
        "",
        "## Issues",
        "",
    ]
    lines.extend([f"- {issue}" for issue in report["issues"]] or ["- None"])
    lines.extend(["", "## Warnings", ""])
    lines.extend([f"- {warning}" for warning in report["warnings"]] or ["- None"])
    lines.extend(
        [
            "",
            "## Stages",
            "",
            f"- First stage: `{stages['first']['id']}` / {stages['first']['name']}",
            f"- Last stage: `{stages['last']['id']}` / {stages['last']['name']}",
            f"- Duplicate stage IDs: {len(stages['duplicateIds'])}",
            "",
            "Service availability counts:",
        ]
    )
    lines.extend([f"- {key}: {value}" for key, value in services.items()])
    lines.extend(
        [
            "",
            "## Lodgings",
            "",
            f"- Duplicate lodging IDs: {len(lodgings['duplicateIds'])}",
            f"- Missing stage links: {lodgings['missingStageCount']}",
            f"- Missing lodging names: {lodgings['missingNameCount']}",
            f"- With GPS location: {lodgings['withLocationCount']}",
            f"- With parsed price: {lodgings['withPriceCount']}",
            "",
            "First lodging samples:",
        ]
    )
    lines.extend(
        [
            f"- `{sample['id']}` / stage `{sample.get('stageId')}` / {sample.get('name')}"
            for sample in lodgings["sample"]
        ]
    )
    lines.extend(
        [
            "",
            "## Route",
            "",
            f"- Version: {metadata['version']}",
            f"- Total distance km: {metadata['totalDistanceKm']}",
            f"- Altitude range m: {metadata['minAltitudeM']} to {metadata['maxAltitudeM']}",
            f"- Bounds: {metadata['bounds']}",
            f"- First point: {route['firstPoint']}",
            f"- Last point: {route['lastPoint']}",
            f"- Distance monotonic issues: {route['distanceIssueCount']}",
            f"- Reverse distance monotonic issues: {route['reverseDistanceIssueCount']}",
            f"- Route marker stage-link issues: {route['markerStageIssueCount']}",
            "",
            "Sample markers:",
        ]
    )
    lines.extend(
        [
            f"- `{marker['id']}` / point {marker['pointIndex']} / {marker['stageName']}"
            for marker in route["sampleMarkers"]
        ]
    )
    lines.append("")
    return "\n".join(lines)


def duplicates(values: list[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


def flatten_route_points(chunks: list[RouteChunk]) -> list[list[float]]:
    points: list[list[float]] = []
    for chunk in sorted(chunks, key=lambda item: item.chunkIndex):
        points.extend(chunk.points)
    return points


def monotonic_issues(values: list[float]) -> list[int]:
    return [index for index in range(1, len(values)) if values[index] < values[index - 1]]


def reverse_monotonic_issues(values: list[float]) -> list[int]:
    return [index for index in range(1, len(values)) if values[index] > values[index - 1]]


def route_chunk_issues(chunks: list[RouteChunk], chunk_size: int) -> list[str]:
    issues: list[str] = []
    sorted_chunks = sorted(chunks, key=lambda item: item.chunkIndex)
    expected_start = 0
    for expected_index, chunk in enumerate(sorted_chunks):
        if chunk.chunkIndex != expected_index:
            issues.append(f"Chunk {chunk.id} has index {chunk.chunkIndex}, expected {expected_index}")
        if chunk.startPointIndex != expected_start:
            issues.append(
                f"Chunk {chunk.id} starts at {chunk.startPointIndex}, expected {expected_start}"
            )
        point_count = len(chunk.points)
        if point_count > chunk_size:
            issues.append(f"Chunk {chunk.id} has {point_count} points, above chunk size {chunk_size}")
        if chunk.endPointIndex != chunk.startPointIndex + point_count - 1:
            issues.append(f"Chunk {chunk.id} endPointIndex does not match point count")
        expected_start = chunk.endPointIndex + 1
    return issues
