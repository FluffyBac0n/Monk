import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../stages/presentation/stages_controller.dart';
import '../data/detour_repository.dart';
import '../domain/trail_detour.dart';

final detourRepositoryProvider = Provider<DetourRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return FirestoreDetourRepository(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
  );
});

final detoursForTrailProvider = FutureProvider<List<TrailDetour>>((ref) {
  return ref
      .watch(detourRepositoryProvider)
      .loadForTrail(trailId: cyprusE4TrailId);
});

final detourRoutesForTrailProvider = FutureProvider<List<TrailDetourRoute>>((
  ref,
) async {
  final detours = await ref.watch(detoursForTrailProvider.future);
  return ref
      .watch(detourRepositoryProvider)
      .loadRoutesForTrail(trailId: cyprusE4TrailId, detours: detours);
});
