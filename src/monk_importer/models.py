from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class GeoPointValue(BaseModel):
    latitude: float
    longitude: float


class StageServices(BaseModel):
    lodging: bool
    tent: bool
    food: bool
    grocery: bool
    drinkableWater: bool
    nonDrinkableWater: bool
    toilets: bool
    medical: bool
    pharmacy: bool
    atm: bool
    busStop: bool


class Stage(BaseModel):
    id: str
    sequence: int
    name: str
    distanceFromPathKm: float | None = None
    accumulatedDistanceKm: float | None = None
    segmentLengthKm: float | None = None
    elevationUpM: float | None = None
    elevationDownM: float | None = None
    altitudeM: float | None = None
    services: StageServices


class LodgingContact(BaseModel):
    phone: str | None = None
    whatsapp: str | None = None
    email: str | None = None
    website: str | None = None
    googleMapsUrl: str | None = None


class Lodging(BaseModel):
    id: str
    stageId: str | None = None
    stageSequence: int | None = None
    stageName: str | None = None
    name: str | None = None
    type: str | None = None
    village: str | None = None
    minPriceText: str | None = None
    priceMinEur: float | None = None
    priceMaxEur: float | None = None
    distanceFromTrailKm: float | None = None
    location: GeoPointValue | None = None
    address: str | None = None
    contact: LodgingContact = Field(default_factory=LodgingContact)
    openingTime: str | None = None
    closingTime: str | None = None
    monthsOpen: str | None = None
    capacityPeople: int | None = None
    checkInTime: str | None = None
    checkOutTime: str | None = None


class RouteMetadata(BaseModel):
    version: int
    pointCount: int
    chunkCount: int
    chunkSize: int
    totalDistanceKm: float
    minAltitudeM: float
    maxAltitudeM: float
    bounds: dict[str, float]
    pointFormat: list[str] = Field(
        default_factory=lambda: ["lat", "lng", "altitudeM", "distanceKm", "reverseDistanceKm"]
    )
    pointStride: int = 5
    reverseDistanceAvailable: bool = True


class RouteChunk(BaseModel):
    id: str
    chunkIndex: int
    startPointIndex: int
    endPointIndex: int
    startDistanceKm: float
    endDistanceKm: float
    bounds: dict[str, float]
    points: list[float]


class RouteMarker(BaseModel):
    id: str
    stageId: str | None = None
    stageName: str
    pointIndex: int
    distanceKm: float
    reverseDistanceKm: float
    location: GeoPointValue
    altitudeM: float


class Excursion(BaseModel):
    id: str
    routeType: Literal["oneWay", "outAndBack", "loop"]
    anchorType: Literal["stage", "trail", "standalone"]
    anchorStageId: str | None = None
    anchorStageSequence: int | None = None
    anchorStageName: str | None = None
    routeVersion: int
    pointCount: int
    chunkCount: int
    chunkSize: int
    routeDistanceKm: float
    totalDistanceKm: float
    routeElevationUpM: float
    routeElevationDownM: float
    elevationUpM: float
    elevationDownM: float
    estimatedWalkingTimeMinutes: int
    minAltitudeM: float
    maxAltitudeM: float
    bounds: dict[str, float]
    startLocation: GeoPointValue
    endLocation: GeoPointValue
    distanceFromTrailKm: float
    mainTrailDistanceKm: float
    excursionConnectionDistanceKm: float
    excursionConnectionSegmentIndex: int
    mainTrailConnectionSegmentIndex: int
    connectionLocation: GeoPointValue
    trailConnectionLocation: GeoPointValue
    pointFormat: list[str] = Field(
        default_factory=lambda: ["lat", "lng", "altitudeM", "distanceKm", "reverseDistanceKm"]
    )
    pointStride: int = 5
    reverseDistanceAvailable: bool = True


class DetourConnection(BaseModel):
    distanceFromTrailKm: float
    mainTrailDistanceKm: float
    mainTrailSegmentIndex: int
    routeLocation: GeoPointValue
    trailLocation: GeoPointValue


class Detour(BaseModel):
    id: str
    name: str
    routeType: Literal["oneWay"] = "oneWay"
    anchorType: Literal["trailSegment"] = "trailSegment"
    routeVersion: int
    pointCount: int
    chunkCount: int
    chunkSize: int
    routeDistanceKm: float
    elevationUpM: float
    elevationDownM: float
    estimatedWalkingTimeMinutes: int
    replacedMainTrailDistanceKm: float
    replacedElevationUpM: float
    replacedElevationDownM: float
    replacedEstimatedWalkingTimeMinutes: int
    distanceDifferenceKm: float
    elevationUpDifferenceM: float
    elevationDownDifferenceM: float
    estimatedWalkingTimeDifferenceMinutes: int
    averageDistanceFromTrailKm: float
    maximumDistanceFromTrailKm: float
    minAltitudeM: float
    maxAltitudeM: float
    bounds: dict[str, float]
    startConnection: DetourConnection
    endConnection: DetourConnection
    affectedStageIds: list[str] = Field(default_factory=list)
    affectedStageSequences: list[int] = Field(default_factory=list)
    affectedStageNames: list[str] = Field(default_factory=list)
    pointFormat: list[str] = Field(
        default_factory=lambda: ["lat", "lng", "altitudeM", "distanceKm", "reverseDistanceKm"]
    )
    pointStride: int = 5
    reverseDistanceAvailable: bool = True


class ImportPayload(BaseModel):
    trailId: str
    trail: dict[str, Any]
    stages: list[Stage]
    lodgings: list[Lodging]
    routeMetadata: RouteMetadata
    routeChunks: list[RouteChunk]
    routeMarkers: list[RouteMarker]
    excursions: list[Excursion] = Field(default_factory=list)
    excursionRouteChunks: dict[str, list[RouteChunk]] = Field(default_factory=dict)
    detours: list[Detour] = Field(default_factory=list)
    detourRouteChunks: dict[str, list[RouteChunk]] = Field(default_factory=dict)
    warnings: list[str] = Field(default_factory=list)
