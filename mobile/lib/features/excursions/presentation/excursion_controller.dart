import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../stages/presentation/stages_controller.dart';
import '../data/excursion_repository.dart';
import '../domain/trail_excursion.dart';

final excursionRepositoryProvider = Provider<ExcursionRepository>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  return FirestoreExcursionRepository(
    firestore: firebaseReady ? FirebaseFirestore.instance : null,
  );
});

final excursionsForTrailProvider = FutureProvider<List<TrailExcursion>>((ref) {
  return ref
      .watch(excursionRepositoryProvider)
      .loadForTrail(trailId: cyprusE4TrailId);
});

final excursionRoutesForTrailProvider =
    FutureProvider<List<TrailExcursionRoute>>((ref) async {
      final excursions = await ref.watch(excursionsForTrailProvider.future);
      return ref
          .watch(excursionRepositoryProvider)
          .loadRoutesForTrail(trailId: cyprusE4TrailId, excursions: excursions);
    });
