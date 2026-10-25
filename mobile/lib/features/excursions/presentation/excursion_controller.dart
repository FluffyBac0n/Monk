import '../../../core/database/database_provider.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../trails/presentation/selected_trail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../data/excursion_repository.dart';
import '../domain/trail_excursion.dart';

final excursionRepositoryProvider = Provider<ExcursionRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return FirestoreExcursionRepository(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
    database: ref.watch(appDatabaseProvider),
  );
});

final excursionsForTrailProvider = FutureProvider<List<TrailExcursion>>((
  ref,
) async {
  try {
    await ref.watch(elevationProvider.future);
  } catch (_) {}
  return ref
      .watch(excursionRepositoryProvider)
      .loadForTrail(trailId: ref.watch(selectedTrailIdProvider));
});

final excursionRoutesForTrailProvider =
    FutureProvider<List<TrailExcursionRoute>>((ref) async {
      final excursions = await ref.watch(excursionsForTrailProvider.future);
      return ref
          .watch(excursionRepositoryProvider)
          .loadRoutesForTrail(
            trailId: ref.watch(selectedTrailIdProvider),
            excursions: excursions,
          );
    });
