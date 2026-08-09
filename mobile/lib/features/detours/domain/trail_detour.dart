import '../../elevation/domain/route_point.dart';

class TrailDetour {
  const TrailDetour({
    required this.id,
    required this.name,
    required this.routeDistanceKm,
    required this.elevationUpM,
    required this.elevationDownM,
    required this.estimatedWalkingTimeMinutes,
    required this.replacedMainTrailDistanceKm,
    required this.replacedElevationUpM,
    required this.replacedElevationDownM,
    required this.replacedEstimatedWalkingTimeMinutes,
    required this.distanceDifferenceKm,
    required this.estimatedWalkingTimeDifferenceMinutes,
    required this.averageDistanceFromTrailKm,
    required this.maximumDistanceFromTrailKm,
    required this.affectedStageIds,
    required this.affectedStageSequences,
    required this.affectedStageNames,
    required this.pointStride,
    this.startMainTrailDistanceKm,
    this.endMainTrailDistanceKm,
  });

  final String id;
  final String name;
  final double routeDistanceKm;
  final double elevationUpM;
  final double elevationDownM;
  final int estimatedWalkingTimeMinutes;
  final double replacedMainTrailDistanceKm;
  final double replacedElevationUpM;
  final double replacedElevationDownM;
  final int replacedEstimatedWalkingTimeMinutes;
  final double distanceDifferenceKm;
  final int estimatedWalkingTimeDifferenceMinutes;
  final double averageDistanceFromTrailKm;
  final double maximumDistanceFromTrailKm;
  final List<String> affectedStageIds;
  final List<int> affectedStageSequences;
  final List<String> affectedStageNames;
  final int pointStride;
  final double? startMainTrailDistanceKm;
  final double? endMainTrailDistanceKm;

  factory TrailDetour.fromFirestore(String id, Map<String, dynamic> json) {
    return TrailDetour(
      id: id,
      name: _stringOrNull(json['name']) ?? _nameFromId(id),
      routeDistanceKm: _doubleOrZero(json['routeDistanceKm']),
      elevationUpM: _doubleOrZero(json['elevationUpM']),
      elevationDownM: _doubleOrZero(json['elevationDownM']),
      estimatedWalkingTimeMinutes:
          _intOrNull(json['estimatedWalkingTimeMinutes']) ?? 0,
      replacedMainTrailDistanceKm: _doubleOrZero(
        json['replacedMainTrailDistanceKm'],
      ),
      replacedElevationUpM: _doubleOrZero(json['replacedElevationUpM']),
      replacedElevationDownM: _doubleOrZero(json['replacedElevationDownM']),
      replacedEstimatedWalkingTimeMinutes:
          _intOrNull(json['replacedEstimatedWalkingTimeMinutes']) ?? 0,
      distanceDifferenceKm: _doubleOrZero(json['distanceDifferenceKm']),
      estimatedWalkingTimeDifferenceMinutes:
          _intOrNull(json['estimatedWalkingTimeDifferenceMinutes']) ?? 0,
      averageDistanceFromTrailKm: _doubleOrZero(
        json['averageDistanceFromTrailKm'],
      ),
      maximumDistanceFromTrailKm: _doubleOrZero(
        json['maximumDistanceFromTrailKm'],
      ),
      affectedStageIds: _stringList(json['affectedStageIds']),
      affectedStageSequences: _intList(json['affectedStageSequences']),
      affectedStageNames: _stringList(json['affectedStageNames']),
      pointStride: (_intOrNull(json['pointStride']) ?? 5).clamp(5, 20),
      startMainTrailDistanceKm: _connectionDistance(json['startConnection']),
      endMainTrailDistanceKm: _connectionDistance(json['endConnection']),
    );
  }
}

class TrailDetourRoute {
  const TrailDetourRoute({required this.detour, required this.points});

  final TrailDetour detour;
  final List<RoutePoint> points;
}

double? _connectionDistance(Object? value) {
  if (value is! Map) return null;
  return _doubleOrNull(value['mainTrailDistanceKm']);
}

String _nameFromId(String id) {
  final words = id
      .split(RegExp(r'[-_\s]+'))
      .where((word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) return id;
  final name = words.join(' ');
  return '${name[0].toUpperCase()}${name.substring(1)}';
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(value.map(_stringOrNull).whereType<String>());
}

List<int> _intList(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(value.map(_intOrNull).whereType<int>());
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
