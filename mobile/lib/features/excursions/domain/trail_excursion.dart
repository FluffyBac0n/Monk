import '../../elevation/domain/route_point.dart';

enum ExcursionRouteType { oneWay, outAndBack, loop }

enum ExcursionAnchorType { stage, trail, standalone }

class ExcursionLocation {
  const ExcursionLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class TrailExcursion {
  const TrailExcursion({
    required this.id,
    required this.routeType,
    required this.anchorType,
    required this.routeDistanceKm,
    required this.totalDistanceKm,
    required this.elevationUpM,
    required this.elevationDownM,
    required this.estimatedWalkingTimeMinutes,
    required this.pointStride,
    this.anchorStageId,
    this.anchorStageSequence,
    this.anchorStageName,
    this.distanceFromTrailKm,
    this.mainTrailDistanceKm,
    this.startLocation,
    this.endLocation,
    this.connectionLocation,
    this.trailConnectionLocation,
  });

  final String id;
  final ExcursionRouteType routeType;
  final ExcursionAnchorType anchorType;
  final String? anchorStageId;
  final int? anchorStageSequence;
  final String? anchorStageName;
  final double routeDistanceKm;
  final double totalDistanceKm;
  final double elevationUpM;
  final double elevationDownM;
  final int estimatedWalkingTimeMinutes;
  final int pointStride;
  final double? distanceFromTrailKm;
  final double? mainTrailDistanceKm;
  final ExcursionLocation? startLocation;
  final ExcursionLocation? endLocation;
  final ExcursionLocation? connectionLocation;
  final ExcursionLocation? trailConnectionLocation;

  String get displayName {
    final stageName = anchorStageName?.trim();
    if (stageName != null && stageName.isNotEmpty) return stageName;
    final words = id
        .split(RegExp(r'[-_\s]+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.isEmpty) return id;
    final name = words.join(' ');
    return '${name[0].toUpperCase()}${name.substring(1)}';
  }

  factory TrailExcursion.fromFirestore(String id, Map<String, dynamic> json) {
    return TrailExcursion(
      id: id,
      routeType: _routeType(json['routeType']),
      anchorType: _anchorType(json['anchorType']),
      anchorStageId: _stringOrNull(json['anchorStageId']),
      anchorStageSequence: _intOrNull(json['anchorStageSequence']),
      anchorStageName: _stringOrNull(json['anchorStageName']),
      routeDistanceKm: _doubleOrZero(json['routeDistanceKm']),
      totalDistanceKm: _doubleOrZero(json['totalDistanceKm']),
      elevationUpM: _doubleOrZero(json['elevationUpM']),
      elevationDownM: _doubleOrZero(json['elevationDownM']),
      estimatedWalkingTimeMinutes:
          _intOrNull(json['estimatedWalkingTimeMinutes']) ?? 0,
      pointStride: (_intOrNull(json['pointStride']) ?? 5).clamp(5, 20),
      distanceFromTrailKm: _doubleOrNull(json['distanceFromTrailKm']),
      mainTrailDistanceKm: _doubleOrNull(json['mainTrailDistanceKm']),
      startLocation: _locationOrNull(json['startLocation']),
      endLocation: _locationOrNull(json['endLocation']),
      connectionLocation: _locationOrNull(json['connectionLocation']),
      trailConnectionLocation: _locationOrNull(json['trailConnectionLocation']),
    );
  }
}

class TrailExcursionRoute {
  const TrailExcursionRoute({required this.excursion, required this.points});

  final TrailExcursion excursion;
  final List<RoutePoint> points;
}

ExcursionRouteType _routeType(Object? value) => switch (value) {
  'outAndBack' => ExcursionRouteType.outAndBack,
  'loop' => ExcursionRouteType.loop,
  _ => ExcursionRouteType.oneWay,
};

ExcursionAnchorType _anchorType(Object? value) => switch (value) {
  'trail' => ExcursionAnchorType.trail,
  'standalone' => ExcursionAnchorType.standalone,
  _ => ExcursionAnchorType.stage,
};

ExcursionLocation? _locationOrNull(Object? value) {
  if (value is! Map) return null;
  final latitude = _doubleOrNull(value['latitude']);
  final longitude = _doubleOrNull(value['longitude']);
  if (latitude == null ||
      longitude == null ||
      latitude < -90 ||
      latitude > 90 ||
      longitude < -180 ||
      longitude > 180) {
    return null;
  }
  return ExcursionLocation(latitude: latitude, longitude: longitude);
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double _doubleOrZero(Object? value) => _doubleOrNull(value) ?? 0;

double? _doubleOrNull(Object? value) {
  final parsed = switch (value) {
    num() => value.toDouble(),
    String() => double.tryParse(value.trim()),
    _ => null,
  };
  return parsed?.isFinite == true ? parsed : null;
}

int? _intOrNull(Object? value) {
  if (value is num && value.toDouble().isFinite) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}
