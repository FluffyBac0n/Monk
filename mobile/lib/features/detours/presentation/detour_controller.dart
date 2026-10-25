import '../../../core/database/database_provider.dart';
import '../../elevation/presentation/elevation_controller.dart';
import '../../trails/presentation/selected_trail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../data/detour_repository.dart';
import '../domain/trail_detour.dart';

final detourRepositoryProvider = Provider<DetourRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return FirestoreDetourRepository(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
    database: ref.watch(appDatabaseProvider),
  );
});

final detoursForTrailProvider = FutureProvider<List<TrailDetour>>((ref) async {
  try {
    await ref.watch(elevationProvider.future);
  } catch (_) {}
  return ref
      .watch(detourRepositoryProvider)
      .loadForTrail(trailId: ref.watch(selectedTrailIdProvider));
});

final detourRoutesForTrailProvider = FutureProvider<List<TrailDetourRoute>>((
  ref,
) async {
  final detours = await ref.watch(detoursForTrailProvider.future);
  return ref
      .watch(detourRepositoryProvider)
      .loadRoutesForTrail(
        trailId: ref.watch(selectedTrailIdProvider),
        detours: detours,
      );
});
