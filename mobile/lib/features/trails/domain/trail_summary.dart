class TrailSummary {
  const TrailSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.distanceKm,
    required this.stageCount,
    required this.highPointM,
    required this.startName,
    required this.endName,
  });

  final String id;
  final String name;
  final String description;
  final double distanceKm;
  final int stageCount;
  final double highPointM;
  final String startName;
  final String endName;
}

const availableTrails = [
  TrailSummary(
    id: 'cyprus-e4',
    name: 'Cyprus E4',
    description:
        'A long-distance journey linking the coast, forests and Troodos mountain.',
    distanceKm: 558,
    stageCount: 123,
    highPointM: 1732,
    startName: 'Pafos Airport',
    endName: 'Larnaka Airport',
  ),
];
