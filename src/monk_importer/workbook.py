from __future__ import annotations

from pathlib import Path

from openpyxl import load_workbook
from openpyxl.worksheet.worksheet import Worksheet

from .models import (
    GeoPointValue,
    ImportPayload,
    Lodging,
    LodgingContact,
    RouteChunk,
    RouteMarker,
    RouteMetadata,
    Stage,
    StageServices,
)
from .utils import (
    clean_text,
    format_time,
    lodging_id,
    parse_coordinates,
    parse_price,
    slugify,
    stage_id,
    to_bool_yn,
    to_float,
    to_int,
)


STAGES_SHEET = "E4 Cyprus STAGES"
LODGING_SHEET = "LODGING"
ROUTE_SHEET = "Map & Elevation"


def build_import_payload(
    workbook_path: Path,
    *,
    trail_id: str = "cyprus-e4",
    route_chunk_size: int = 500,
    route_version: int = 1,
) -> ImportPayload:
    workbook_values = load_workbook(workbook_path, data_only=True, read_only=True)

    stages = parse_stages(workbook_values[STAGES_SHEET])
    stage_lookup = {stage.name: stage.id for stage in stages}
    stage_slug_lookup = {slugify(stage.name): stage.id for stage in stages}
    lodgings, lodging_warnings = parse_lodgings(
        workbook_values[LODGING_SHEET],
        stage_lookup,
        stage_slug_lookup,
    )
    route_metadata, route_chunks, route_markers = parse_route(
        workbook_values[ROUTE_SHEET],
        stages_by_name=stage_lookup,
        stages_by_slug=stage_slug_lookup,
        chunk_size=route_chunk_size,
        version=route_version,
    )

    trail = {
        "id": trail_id,
        "name": "Cyprus E4",
        "country": "Cyprus",
        "stageCount": len(stages),
        "lodgingCount": len(lodgings),
        "routePointCount": route_metadata.pointCount,
        "totalDistanceKm": route_metadata.totalDistanceKm,
        "startStageId": stages[0].id if stages else None,
        "startStageName": stages[0].name if stages else None,
        "endStageId": stages[-1].id if stages else None,
        "endStageName": stages[-1].name if stages else None,
        "routeVersion": route_version,
    }

    return ImportPayload(
        trailId=trail_id,
        trail=trail,
        stages=stages,
        lodgings=lodgings,
        routeMetadata=route_metadata,
        routeChunks=route_chunks,
        routeMarkers=route_markers,
        warnings=lodging_warnings,
    )


def parse_stages(sheet: Worksheet) -> list[Stage]:
    stages: list[Stage] = []
    for row in sheet.iter_rows(min_row=2, values_only=True):
        sequence = to_int(row[0])
        name = clean_text(row[3])
        doc_id = stage_id(sequence, name)
        if sequence is None or name is None or doc_id is None:
            continue
        stages.append(
            Stage(
                id=doc_id,
                sequence=sequence,
                name=name,
                distanceFromPathKm=to_float(row[1]),
                accumulatedDistanceKm=to_float(row[2]),
                segmentLengthKm=to_float(row[4]),
                elevationUpM=to_float(row[5]),
                elevationDownM=to_float(row[6]),
                altitudeM=to_float(row[7]),
                services=StageServices(
                    lodging=to_bool_yn(row[8]),
                    tent=to_bool_yn(row[9]),
                    food=to_bool_yn(row[10]),
                    grocery=to_bool_yn(row[11]),
                    drinkableWater=to_bool_yn(row[12]),
                    nonDrinkableWater=to_bool_yn(row[13]),
                    toilets=to_bool_yn(row[14]),
                    medical=to_bool_yn(row[15]),
                    pharmacy=to_bool_yn(row[16]),
                    atm=to_bool_yn(row[17]),
                    busStop=to_bool_yn(row[18]),
                ),
            )
        )
    return stages


def parse_lodgings(
    sheet: Worksheet,
    stage_lookup: dict[str, str],
    stage_slug_lookup: dict[str, str],
) -> tuple[list[Lodging], list[str]]:
    lodgings: list[Lodging] = []
    warnings: list[str] = []
    for row_number, row in enumerate(sheet.iter_rows(min_row=2, values_only=True), start=2):
        stage_sequence = to_int(row[0])
        stage_name = clean_text(row[1])
        lodging_name = clean_text(row[2])
        if stage_sequence is None and stage_name is None and lodging_name is None:
            continue

        doc_id = lodging_id(stage_sequence, stage_name, lodging_name, row_number)
        price_text, price_min, price_max = parse_price(row[3])
        coords = parse_coordinates(row[9])
        resolved_stage_id = resolve_stage_id(stage_name, stage_lookup, stage_slug_lookup)
        if stage_name and not resolved_stage_id:
            warnings.append(f"LODGING row {row_number}: unknown stage '{stage_name}'")

        lodgings.append(
            Lodging(
                id=doc_id,
                stageId=resolved_stage_id,
                stageSequence=stage_sequence,
                stageName=stage_name,
                name=lodging_name,
                minPriceText=price_text,
                priceMinEur=price_min,
                priceMaxEur=price_max,
                distanceFromTrailKm=to_float(row[4]),
                village=clean_text(row[5]),
                type=clean_text(row[6]),
                location=GeoPointValue(latitude=coords[0], longitude=coords[1]) if coords else None,
                address=clean_text(row[10]),
                contact=LodgingContact(
                    phone=clean_text(row[7]),
                    googleMapsUrl=clean_text(row[8]),
                    website=clean_text(row[11]),
                    whatsapp=clean_text(row[12]),
                    email=clean_text(row[13]),
                ),
                openingTime=format_time(row[14]),
                closingTime=format_time(row[15]),
                monthsOpen=clean_text(row[16]),
                capacityPeople=to_int(row[17]),
                checkInTime=format_time(row[18]),
                checkOutTime=format_time(row[19]),
            )
        )

    return lodgings, warnings


def parse_route(
    sheet: Worksheet,
    *,
    stages_by_name: dict[str, str],
    stages_by_slug: dict[str, str],
    chunk_size: int,
    version: int,
) -> tuple[RouteMetadata, list[RouteChunk], list[RouteMarker]]:
    points: list[dict[str, float | str | None]] = []
    markers: list[RouteMarker] = []
    marker_id_counts: dict[str, int] = {}

    for point_index, row in enumerate(sheet.iter_rows(min_row=2, values_only=True)):
        lat = to_float(row[0])
        lng = to_float(row[1])
        altitude = to_float(row[2])
        distance = to_float(row[3])
        reverse_distance = to_float(row[4])
        stage_name = clean_text(row[5])
        if lat is None or lng is None or altitude is None or distance is None or reverse_distance is None:
            continue

        points.append(
            {
                "lat": lat,
                "lng": lng,
                "altitudeM": altitude,
                "distanceKm": distance,
                "reverseDistanceKm": reverse_distance,
            }
        )

        if stage_name:
            resolved_stage_id = resolve_stage_id(stage_name, stages_by_name, stages_by_slug)
            marker_id = resolved_stage_id or f"route-marker-{point_index:05d}"
            marker_id_counts[marker_id] = marker_id_counts.get(marker_id, 0) + 1
            if marker_id_counts[marker_id] > 1:
                marker_id = f"{marker_id}-{point_index:05d}"
            markers.append(
                RouteMarker(
                    id=marker_id,
                    stageId=resolved_stage_id,
                    stageName=stage_name,
                    pointIndex=point_index,
                    distanceKm=distance,
                    reverseDistanceKm=reverse_distance,
                    altitudeM=altitude,
                    location=GeoPointValue(latitude=lat, longitude=lng),
                )
            )

    chunks = build_route_chunks(points, chunk_size)
    lats = [float(point["lat"]) for point in points]
    lngs = [float(point["lng"]) for point in points]
    altitudes = [float(point["altitudeM"]) for point in points]
    distances = [float(point["distanceKm"]) for point in points]

    metadata = RouteMetadata(
        version=version,
        pointCount=len(points),
        chunkCount=len(chunks),
        chunkSize=chunk_size,
        totalDistanceKm=max(distances) if distances else 0,
        minAltitudeM=min(altitudes) if altitudes else 0,
        maxAltitudeM=max(altitudes) if altitudes else 0,
        bounds={
            "minLat": min(lats) if lats else 0,
            "maxLat": max(lats) if lats else 0,
            "minLng": min(lngs) if lngs else 0,
            "maxLng": max(lngs) if lngs else 0,
        },
    )
    return metadata, chunks, markers


def resolve_stage_id(
    stage_name: str | None,
    stages_by_name: dict[str, str],
    stages_by_slug: dict[str, str],
) -> str | None:
    if not stage_name:
        return None
    return stages_by_name.get(stage_name) or stages_by_slug.get(slugify(stage_name))


def build_route_chunks(points: list[dict[str, float | str | None]], chunk_size: int) -> list[RouteChunk]:
    chunks: list[RouteChunk] = []
    for chunk_index, start in enumerate(range(0, len(points), chunk_size)):
        chunk_points = points[start : start + chunk_size]
        end = start + len(chunk_points) - 1
        compact_points = [
            value
            for point in chunk_points
            for value in [
                float(point["lat"]),
                float(point["lng"]),
                float(point["altitudeM"]),
                float(point["distanceKm"]),
                float(point["reverseDistanceKm"]),
            ]
        ]
        grouped_points = group_flat_points(compact_points)
        lats = [point[0] for point in grouped_points]
        lngs = [point[1] for point in grouped_points]
        distances = [point[3] for point in grouped_points]
        chunks.append(
            RouteChunk(
                id=f"{chunk_index:04d}",
                chunkIndex=chunk_index,
                startPointIndex=start,
                endPointIndex=end,
                startDistanceKm=min(distances),
                endDistanceKm=max(distances),
                bounds={
                    "minLat": min(lats),
                    "maxLat": max(lats),
                    "minLng": min(lngs),
                    "maxLng": max(lngs),
                },
                points=compact_points,
            )
        )
    return chunks


def group_flat_points(points: list[float], stride: int = 5) -> list[list[float]]:
    return [points[index : index + stride] for index in range(0, len(points), stride)]
