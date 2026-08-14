from math import isclose

import pytest
from openpyxl import Workbook

from eurotrex_importer.geometry import closest_polyline_match, cumulative_distances_km
from eurotrex_importer.models import Stage, StageServices
from eurotrex_importer.workbook import parse_excursions


def test_closest_polyline_match_detects_crossing_segments() -> None:
    match = closest_polyline_match(
        [(0.0, -0.01), (0.0, 0.01)],
        [(-0.01, 0.0), (0.01, 0.0)],
    )

    assert match.distanceKm < 1e-9
    assert match.firstLocation == pytest.approx((0.0, 0.0))
    assert match.secondLocation == pytest.approx((0.0, 0.0))


def test_parse_excursion_calculates_out_and_back_totals_and_trail_match() -> None:
    sheet = _excursion_sheet(
        [
            [0.001, 0.0, 10.0, "ridge-walk", "outAndBack", "trail", None],
            [0.001, 0.01, 110.0, None, None, None, None],
        ]
    )
    main_route = _main_route([(0.0, 0.0), (0.0, 0.02)])

    excursions, chunks, warnings = parse_excursions(
        sheet,
        stages_by_sequence={},
        main_route_points=main_route,
        chunk_size=500,
        version=3,
    )

    excursion = excursions[0]
    assert excursion.id == "ridge-walk"
    assert excursion.routeType == "outAndBack"
    assert excursion.anchorType == "trail"
    assert excursion.routeVersion == 3
    assert isclose(excursion.totalDistanceKm, excursion.routeDistanceKm * 2)
    assert excursion.routeElevationUpM == 100
    assert excursion.routeElevationDownM == 0
    assert excursion.elevationUpM == 100
    assert excursion.elevationDownM == 100
    assert excursion.distanceFromTrailKm == pytest.approx(0.111195, rel=1e-3)
    assert excursion.mainTrailDistanceKm == pytest.approx(0.0, abs=1e-8)
    assert excursion.pointCount == 2
    assert len(chunks[excursion.id]) == 1
    assert warnings == []


def test_stage_anchor_uses_metadata_row_and_resolves_stage() -> None:
    sheet = _excursion_sheet(
        [
            [0.001, 0.0, 10.0, "stage-spur", "oneWay", "stage", 101],
            [0.0, 0.01, 20.0, None, None, None, None],
        ]
    )
    main_route = _main_route([(0.0, 0.0), (0.0, 0.02)])
    stage = _stage(101, "Stage 101")

    excursions, _, _ = parse_excursions(
        sheet,
        stages_by_sequence={101: stage},
        main_route_points=main_route,
        chunk_size=500,
        version=1,
    )

    excursion = excursions[0]
    assert excursion.anchorStageId == stage.id
    assert excursion.anchorStageSequence == 101
    assert excursion.anchorStageName == "Stage 101"
    assert excursion.distanceFromTrailKm == pytest.approx(0.111195, rel=1e-3)
    assert excursion.excursionConnectionDistanceKm == 0
    assert excursion.connectionLocation.latitude == pytest.approx(0.001)
    assert excursion.connectionLocation.longitude == pytest.approx(0.0)


@pytest.mark.parametrize("route_type", ["oneWay", "outAndBack", "loop"])
def test_only_supported_route_types_are_accepted(route_type: str) -> None:
    sheet = _excursion_sheet(
        [
            [0.0, 0.0, 0.0, "test", route_type, "standalone", None],
            [0.0, 0.01, 0.0, None, None, None, None],
        ]
    )

    excursions, _, _ = parse_excursions(
        sheet,
        stages_by_sequence={},
        main_route_points=_main_route([(0.0, 0.0), (0.0, 0.02)]),
        chunk_size=500,
        version=1,
    )

    assert excursions[0].routeType == route_type


def test_unknown_route_type_is_rejected() -> None:
    sheet = _excursion_sheet(
        [
            [0.0, 0.0, 0.0, "test", "circular", "standalone", None],
            [0.0, 0.01, 0.0, None, None, None, None],
        ]
    )

    with pytest.raises(ValueError, match="Route Type must be oneWay, outAndBack, or loop"):
        parse_excursions(
            sheet,
            stages_by_sequence={},
            main_route_points=_main_route([(0.0, 0.0), (0.0, 0.02)]),
            chunk_size=500,
            version=1,
        )


def _excursion_sheet(rows: list[list[object]]) -> object:
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Excursions"
    sheet.append(
        [
            "Latitude",
            "Longitude",
            "Altitude",
            "Excursion ID",
            "Route Type",
            "Anchor Type",
            "Anchor Stage",
        ]
    )
    for row in rows:
        sheet.append(row)
    return sheet


def _main_route(locations: list[tuple[float, float]]) -> list[list[float]]:
    distances = cumulative_distances_km(locations)
    total = distances[-1]
    return [
        [location[0], location[1], 0.0, distances[index], total - distances[index]]
        for index, location in enumerate(locations)
    ]


def _stage(sequence: int, name: str) -> Stage:
    return Stage(
        id=f"{sequence}-stage-{sequence}",
        sequence=sequence,
        name=name,
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
