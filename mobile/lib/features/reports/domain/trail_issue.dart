class TrailIssue {
  const TrailIssue({
    required this.id,
    required this.trailId,
    required this.category,
    required this.description,
    required this.passability,
    required this.latitude,
    required this.longitude,
  });
  final String id, trailId, category, description, passability;
  final double latitude, longitude;

  static TrailIssue? fromMap(String id, Map<String, dynamic> data) {
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    if (!['reviewed', 'forwarded'].contains(data['status']) ||
        latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        data['trailId'] is! String ||
        data['description'] is! String ||
        (data['description'] as String).trim().isEmpty) {
      return null;
    }
    return TrailIssue(
      id: id,
      trailId: data['trailId'] as String,
      category: data['category'] as String? ?? 'other',
      description: data['description'] as String,
      passability: data['passability'] as String? ?? 'unsure',
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  }
}
