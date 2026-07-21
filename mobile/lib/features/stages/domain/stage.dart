class TrailStage {
  const TrailStage({
    required this.id,
    required this.sequence,
    required this.name,
    required this.services,
    this.accumulatedDistanceKm,
    this.segmentLengthKm,
    this.altitudeM,
  });

  final String id;
  final int sequence;
  final String name;
  final double? accumulatedDistanceKm;
  final double? segmentLengthKm;
  final double? altitudeM;
  final Map<String, bool> services;

  factory TrailStage.fromFirestore(String id, Map<String, dynamic> json) {
    final rawServices = json['services'] as Map<String, dynamic>? ?? const {};
    return TrailStage(
      id: id,
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? 'Unnamed stage',
      accumulatedDistanceKm: (json['accumulatedDistanceKm'] as num?)
          ?.toDouble(),
      segmentLengthKm: (json['segmentLengthKm'] as num?)?.toDouble(),
      altitudeM: (json['altitudeM'] as num?)?.toDouble(),
      services: rawServices.map((key, value) => MapEntry(key, value == true)),
    );
  }
}
