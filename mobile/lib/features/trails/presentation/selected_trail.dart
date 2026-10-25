import 'dart:convert';
import '../../../core/database/database_provider.dart';
import '../../elevation/presentation/elevation_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';
import '../domain/trail_summary.dart';

class SelectedTrailController extends Notifier<String> {
  @override
  String build() => 'cyprus-e4';
  void select(String trailId) => state = trailId;
}

final selectedTrailIdProvider =
    NotifierProvider<SelectedTrailController, String>(
      SelectedTrailController.new,
    );
final publishedTrailsProvider = FutureProvider<List<TrailSummary>>((ref) async {
  if (!ref.watch(firebaseReadyProvider)) return availableTrails;
  final snapshot = await FirebaseFirestore.instance.collection('trails').get();
  final trails = snapshot.docs
      .where((d) => d.data()['publishedReleaseId'] is String)
      .map((d) {
        final data = d.data();
        return TrailSummary(
          id: d.id,
          name: data['name'] as String? ?? d.id,
          description: data['description'] as String? ?? '',
          distanceKm: (data['totalDistanceKm'] as num?)?.toDouble() ?? 0,
          stageCount: (data['stageCount'] as num?)?.toInt() ?? 0,
          highPointM: (data['maxAltitudeM'] as num?)?.toDouble() ?? 0,
          startName: data['startName'] as String? ?? '',
          endName: data['endName'] as String? ?? '',
        );
      })
      .toList();
  if (!trails.any((t) => t.id == 'cyprus-e4')) {
    trails.insert(0, availableTrails.first);
  }
  return trails;
});

final activeReleaseMetadataProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final id = ref.watch(selectedTrailIdProvider);
  ref.watch(elevationProvider);
  try {
    final settings = await ref.read(appDatabaseProvider).readSettings();
    final value = settings['trailReleaseMeta:$id'];
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  } catch (_) {
    return {};
  }
});
