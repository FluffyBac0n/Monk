class TrailStage {
  const TrailStage({
    required this.id,
    required this.sequence,
    required this.name,
    required this.services,
    this.distanceFromPathKm,
    this.accumulatedDistanceKm,
    this.segmentLengthKm,
    this.elevationUpM,
    this.elevationDownM,
    this.altitudeM,
  });

  final String id;
  final int sequence;
  final String name;
  final double? distanceFromPathKm;
  final double? accumulatedDistanceKm;
  final double? segmentLengthKm;
  final double? elevationUpM;
  final double? elevationDownM;
  final double? altitudeM;
  final Map<String, bool> services;

  factory TrailStage.fromFirestore(String id, Map<String, dynamic> json) {
    final rawServices = json['services'] as Map<String, dynamic>? ?? const {};
    return TrailStage(
      id: id,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unnamed stage',
      distanceFromPathKm: (json['distanceFromPathKm'] as num?)?.toDouble(),
      accumulatedDistanceKm: (json['accumulatedDistanceKm'] as num?)
          ?.toDouble(),
      segmentLengthKm: (json['segmentLengthKm'] as num?)?.toDouble(),
      elevationUpM: (json['elevationUpM'] as num?)?.toDouble(),
      elevationDownM: (json['elevationDownM'] as num?)?.toDouble(),
      altitudeM: (json['altitudeM'] as num?)?.toDouble(),
      services: rawServices.map((key, value) => MapEntry(key, value == true)),
    );
  }
}

const stageOnTrailThresholdKm = 0.5;

bool? stageIsOnTrail(TrailStage stage) {
  final distanceKm = stage.distanceFromPathKm;
  if (distanceKm == null || !distanceKm.isFinite || distanceKm < 0) {
    return null;
  }
  return distanceKm < stageOnTrailThresholdKm;
}
