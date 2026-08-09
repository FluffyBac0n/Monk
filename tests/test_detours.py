from __future__ import annotations

import pytest
from openpyxl import Workbook

from monk_importer.geometry import cumulative_distances_km
from monk_importer.models import Stage, StageServices
from monk_importer.workbook import parse_detours


def test_parse_detour_calculates_connections_replaced_route_and_differences() -> None:
    sheet = _detour_sheet(
        [
            [0.0, 0.0, 0.0, "ridge-alternative", "Ridge Alternative"],
            [0.005, 0.01, 200.0, None, None],
            [0.0, 0.02, 50.0, None, None],
        ]
    )
    main_route = _main_route(
        [
            (0.0, 0.0, 0.0),
            (0.0, 0.01, 100.0),
            (0.0, 0.02, 50.0),
        ]
    )
    stages = [
        _stage(3, "Start", 0.0),
        _stage(2, "Middle", main_route[1][3]),
        _stage(1, "Finish", main_route[2][3]),
    ]

    detours, chunks, warnings = parse_detours(
        sheet,
        stages=stages,
        main_route_points=main_route,
        chunk_size=500,
        version=4,
    )

    detour = detours[0]
    assert detour.id == "ridge-alternative"
    assert detour.name == "Ridge Alternative"
    assert detour.routeType == "oneWay"
    assert detour.anchorType == "trailSegment"
    assert detour.routeVersion == 4
    assert detour.pointCount == 3
    assert detour.chunkCount == 1
    assert detour.startConnection.distanceFromTrailKm == pytest.approx(0.0, abs=1e-8)
    assert detour.endConnection.distanceFromTrailKm == pytest.approx(0.0, abs=1e-8)
    assert detour.startConnection.mainTrailDistanceKm == pytest.approx(0.0, abs=1e-8)
    assert detour.endConnection.mainTrailDistanceKm == pytest.approx(main_route[-1][3], rel=1e-6)
    assert detour.replacedMainTrailDistanceKm == pytest.approx(main_route[-1][3], rel=1e-6)
    assert detour.routeDistanceKm > detour.replacedMainTrailDistanceKm
    assert detour.distanceDifferenceKm == pytest.approx(
        detour.routeDistanceKm - detour.replacedMainTrailDistanceKm
    )
    assert detour.elevationUpM == 200
    assert detour.elevationDownM == 150
    assert detour.replacedElevationUpM == 100
    assert detour.replacedElevationDownM == 50
    assert detour.maximumDistanceFromTrailKm > 0.5
    assert detour.affectedStageSequences == [2, 1]
    assert len(chunks[detour.id]) == 1
    assert warnings == []


def test_detour_warns_when_an_endpoint_does_not_connect_to_the_e4() -> None:
    sheet = _detour_sheet(
        [
            [0.01, 0.0, 0.0, "remote-route", "Remote Route"],
            [0.0, 0.02, 0.0, None, None],
        ]
    )

    _, _, warnings = parse_detours(
        sheet,
        stages=[],
        main_route_points=_main_route([(0.0, 0.0, 0.0), (0.0, 0.02, 0.0)]),
        chunk_size=500,
        version=1,
    )

    assert any("start is" in warning and "from the E4" in warning for warning in warnings)


def test_duplicate_detour_ids_are_rejected() -> None:
    sheet = _detour_sheet(
        [
            [0.0, 0.0, 0.0, "duplicate", "First"],
            [0.0, 0.01, 0.0, None, None],
            [0.0, 0.01, 0.0, "duplicate", "Second"],
            [0.0, 0.02, 0.0, None, None],
        ]
    )

    with pytest.raises(ValueError, match="Duplicate Detour ID"):
        parse_detours(
            sheet,
            stages=[],
            main_route_points=_main_route([(0.0, 0.0, 0.0), (0.0, 0.02, 0.0)]),
            chunk_size=500,
            version=1,
        )


def _detour_sheet(rows: list[list[object]]) -> object:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Detours"
    sheet.append(["Latitude", "Longitude", "Altitude", "Detour ID", "Detour Name"])
    for row in rows:
        sheet.append(row)
    return sheet


def _main_route(locations: list[tuple[float, float, float]]) -> list[list[float]]:
    distances = cumulative_distances_km([(lat, lng) for lat, lng, _ in locations])
    total = distances[-1]
    return [
        [lat, lng, altitude, distances[index], total - distances[index]]
        for index, (lat, lng, altitude) in enumerate(locations)
    ]


def _stage(sequence: int, name: str, accumulated_distance_km: float) -> Stage:
    return Stage(
        id=f"{sequence}-{name.lower()}",
        sequence=sequence,
        name=name,
        accumulatedDistanceKm=accumulated_distance_km,
        services=StageServices(
            lodging=False,
            tent=False,
            food=False,
            grocery=False,
            drinkableWater=False,
            nonDrinkableWater=False,
            toilets=False,
            medical=False,
            pharmacy=False,
            atm=False,
            busStop=False,
        ),
    )
