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
    excursion_ids = [excursion.id for excursion in payload.excursions]
    detour_ids = [detour.id for detour in payload.detours]
    known_stage_ids = set(stage_ids)

    stage_duplicate_ids = duplicates(stage_ids)
    lodging_duplicate_ids = duplicates(lodging_ids)
    marker_duplicate_ids = duplicates(route_marker_ids)
    excursion_duplicate_ids = duplicates(excursion_ids)
    detour_duplicate_ids = duplicates(detour_ids)
    orphan_excursion_chunk_sets = sorted(
        set(payload.excursionRouteChunks).difference(excursion_ids)
    )
    orphan_detour_chunk_sets = sorted(set(payload.detourRouteChunks).difference(detour_ids))

    lodgings_missing_stage = [
        lodging.id
        for lodging in payload.lodgings
        if lodging.stageId is None or lodging.stageId not in known_stage_ids
    ]
    lodgings_missing_name = [lodging.id for lodging in payload.lodgings if not lodging.name]
    lodgings_with_location = [
        lodging.id for lodging in payload.lodgings if lodging.location is not None
    ]
    lodgings_with_price = [
        lodging.id for lodging in payload.lodgings if lodging.priceMinEur is not None
    ]

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
    excursion_issues: list[str] = []
    excursion_route_point_count = 0
    for excursion in payload.excursions:
        chunks = payload.excursionRouteChunks.get(excursion.id, [])
        points = flatten_route_points(chunks)
        excursion_route_point_count += len(points)
        if len(points) != excursion.pointCount:
            excursion_issues.append(
                f"Excursion {excursion.id} point count mismatch: "
                f"metadata={excursion.pointCount}, chunks={len(points)}"
            )
        for chunk_issue in route_chunk_issues(chunks, excursion.chunkSize):
            excursion_issues.append(f"Excursion {excursion.id}: {chunk_issue}")
        if excursion.chunkCount != len(chunks):
            excursion_issues.append(
                f"Excursion {excursion.id} chunk count mismatch: "
                f"metadata={excursion.chunkCount}, chunks={len(chunks)}"
            )
        distance_issue_count = len(monotonic_issues([point[3] for point in points]))
        reverse_issue_count = len(reverse_monotonic_issues([point[4] for point in points]))
        if distance_issue_count:
            excursion_issues.append(
                f"Excursion {excursion.id} distance is not increasing at "
                f"{distance_issue_count} points"
            )
        if reverse_issue_count:
            excursion_issues.append(
                f"Excursion {excursion.id} reverse distance is not decreasing at "
                f"{reverse_issue_count} points"
            )
        if excursion.anchorType == "stage" and excursion.anchorStageId not in known_stage_ids:
            excursion_issues.append(
                f"Excursion {excursion.id} does not map to a known anchor stage"
            )

    detour_issues: list[str] = []
    detour_route_point_count = 0
    for detour in payload.detours:
        chunks = payload.detourRouteChunks.get(detour.id, [])
        points = flatten_route_points(chunks)
        detour_route_point_count += len(points)
        if len(points) != detour.pointCount:
            detour_issues.append(
                f"Detour {detour.id} point count mismatch: "
                f"metadata={detour.pointCount}, chunks={len(points)}"
            )
        for chunk_issue in route_chunk_issues(chunks, detour.chunkSize):
            detour_issues.append(f"Detour {detour.id}: {chunk_issue}")
        if detour.chunkCount != len(chunks):
            detour_issues.append(
                f"Detour {detour.id} chunk count mismatch: "
                f"metadata={detour.chunkCount}, chunks={len(chunks)}"
            )
        distance_issue_count = len(monotonic_issues([point[3] for point in points]))
        reverse_issue_count = len(reverse_monotonic_issues([point[4] for point in points]))
        if distance_issue_count:
            detour_issues.append(
                f"Detour {detour.id} distance is not increasing at {distance_issue_count} points"
            )
        if reverse_issue_count:
            detour_issues.append(
                f"Detour {detour.id} reverse distance is not decreasing at "
                f"{reverse_issue_count} points"
            )
        unknown_stage_ids = sorted(set(detour.affectedStageIds).difference(known_stage_ids))
        if unknown_stage_ids:
            detour_issues.append(
                f"Detour {detour.id} maps to unknown affected stages: {unknown_stage_ids}"
            )

    issues = []
    warnings = list(payload.warnings)
    if not stage_ids:
        issues.append("No stages were parsed from the workbook")
    if not route_points:
        issues.append("No route points were parsed from the workbook")
    if not payload.routeChunks:
        issues.append("No route chunks were generated from the workbook")
    if stage_duplicate_ids:
        issues.append(f"Duplicate stage IDs: {stage_duplicate_ids}")
    if lodging_duplicate_ids:
        issues.append(f"Duplicate lodging IDs: {lodging_duplicate_ids}")
    if marker_duplicate_ids:
        issues.append(f"Duplicate route marker IDs: {marker_duplicate_ids}")
    if excursion_duplicate_ids:
        issues.append(f"Duplicate excursion IDs: {excursion_duplicate_ids}")
    if detour_duplicate_ids:
        issues.append(f"Duplicate detour IDs: {detour_duplicate_ids}")
    if orphan_excursion_chunk_sets:
        issues.append(
            f"Excursion route chunks without a summary document: {orphan_excursion_chunk_sets}"
        )
    if orphan_detour_chunk_sets:
        issues.append(f"Detour route chunks without a summary document: {orphan_detour_chunk_sets}")
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
        issues.append(
            f"Route accumulated distance is not increasing at {len(distance_issues)} points"
        )
    if reverse_distance_issues:
        issues.append(
            f"Route reverse distance is not decreasing at {len(reverse_distance_issues)} points"
        )
    if chunk_issues:
        issues.extend(chunk_issues)
    if excursion_issues:
        issues.extend(excursion_issues)
    if detour_issues:
        issues.extend(detour_issues)
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
            "excursions": len(payload.excursions),
            "excursionRoutePoints": excursion_route_point_count,
            "detours": len(payload.detours),
            "detourRoutePoints": detour_route_point_count,
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
        "excursions": {
            "duplicateIds": excursion_duplicate_ids,
            "orphanChunkSets": orphan_excursion_chunk_sets,
            "issues": excursion_issues,
            "samples": [excursion.model_dump(mode="json") for excursion in payload.excursions[:5]],
        },
        "detours": {
            "duplicateIds": detour_duplicate_ids,
            "orphanChunkSets": orphan_detour_chunk_sets,
            "issues": detour_issues,
            "samples": [detour.model_dump(mode="json") for detour in payload.detours[:5]],
        },
    }


def write_validation_report(
    report: dict[str, Any], markdown_path: Path, json_path: Path | None = None
) -> None:
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
    excursions = report["excursions"]
    detours = report["detours"]
    services = stages["servicesSummary"]
    metadata = route["metadata"]

    lines = [
        "# EuroTrex Import Validation Report",
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
        f"- Excursions: {counts['excursions']}",
        f"- Excursion route points: {counts['excursionRoutePoints']}",
        f"- Detours: {counts['detours']}",
        f"- Detour route points: {counts['detourRoutePoints']}",
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
    lines.extend(
        [
            "",
            "## Excursions",
            "",
            f"- Duplicate excursion IDs: {len(excursions['duplicateIds'])}",
            f"- Orphan excursion chunk sets: {len(excursions['orphanChunkSets'])}",
            f"- Excursion validation issues: {len(excursions['issues'])}",
            "",
            "Excursion samples:",
        ]
    )
    lines.extend(
        [
            f"- `{sample['id']}` / {sample['routeType']} / {sample['anchorType']} / "
            f"{sample['totalDistanceKm']:.3f} km"
            for sample in excursions["samples"]
        ]
    )
    lines.extend(
        [
            "",
            "## Detours",
            "",
            f"- Duplicate detour IDs: {len(detours['duplicateIds'])}",
            f"- Orphan detour chunk sets: {len(detours['orphanChunkSets'])}",
            f"- Detour validation issues: {len(detours['issues'])}",
            "",
            "Detour samples:",
        ]
    )
    lines.extend(
        [
            f"- `{sample['id']}` / replaces {sample['replacedMainTrailDistanceKm']:.3f} km / "
            f"detour {sample['routeDistanceKm']:.3f} km"
            for sample in detours["samples"]
        ]
    )
    lines.append("")
    return "\n".join(lines)


def duplicates(values: list[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


def flatten_route_points(chunks: list[RouteChunk]) -> list[list[float]]:
    points: list[list[float]] = []
    for chunk in sorted(chunks, key=lambda item: item.chunkIndex):
        points.extend(group_flat_points(chunk.points))
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
            issues.append(
                f"Chunk {chunk.id} has index {chunk.chunkIndex}, expected {expected_index}"
            )
        if chunk.startPointIndex != expected_start:
            issues.append(
                f"Chunk {chunk.id} starts at {chunk.startPointIndex}, expected {expected_start}"
            )
        point_count = len(chunk.points)
        if point_count % 5 != 0:
            issues.append(f"Chunk {chunk.id} flat point array is not divisible by stride 5")
        point_count = point_count // 5
        if point_count > chunk_size:
            issues.append(
                f"Chunk {chunk.id} has {point_count} points, above chunk size {chunk_size}"
            )
        if chunk.endPointIndex != chunk.startPointIndex + point_count - 1:
            issues.append(f"Chunk {chunk.id} endPointIndex does not match point count")
        expected_start = chunk.endPointIndex + 1
    return issues


def group_flat_points(points: list[float], stride: int = 5) -> list[list[float]]:
    return [points[index : index + stride] for index in range(0, len(points), stride)]
