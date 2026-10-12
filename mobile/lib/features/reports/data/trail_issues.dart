import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app.dart';
import '../domain/trail_issue.dart';

final trailIssuesProvider = StreamProvider.autoDispose
    .family<List<TrailIssue>, String>((ref, trailId) {
      if (!ref.watch(firebaseReadyProvider)) return Stream.value(const []);
      // Listen only to the deliberately public projection, never private reports.
      // Firestore delivers removals as well as new/changed approved issues.
      return FirebaseFirestore.instance
          .collection('trailIssues')
          .where('trailId', isEqualTo: trailId)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                ?TrailIssue.fromMap(doc.id, doc.data()),
            ],
          );
    });
