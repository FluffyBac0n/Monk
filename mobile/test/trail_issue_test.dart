import 'dart:async';
import 'package:eurotrex/features/reports/domain/trail_issue.dart';
import 'package:eurotrex/features/reports/data/trail_issues.dart';
import 'package:eurotrex/features/reports/presentation/trail_issue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const issue = TrailIssue(
  id: 'approved',
  trailId: 'cyprus-e4',
  category: 'signpost',
  description: 'Broken sign at the junction.',
  passability: 'difficult',
  latitude: 34.89,
  longitude: 32.867,
);
void main() {
  test('only active official issues with valid coordinates are accepted', () {
    final data = {
      'trailId': 'cyprus-e4',
      'status': 'reviewed',
      'description': 'Broken sign',
      'category': 'signpost',
      'latitude': 35.0,
      'longitude': 33.0,
    };
    expect(TrailIssue.fromMap('one', data), isNotNull);
    for (final status in ['new', 'resolved', 'duplicate', 'dismissed']) {
      expect(TrailIssue.fromMap('one', {...data, 'status': status}), isNull);
    }
    expect(
      TrailIssue.fromMap('one', {...data, 'status': 'forwarded'}),
      isNotNull,
    );
    expect(
      TrailIssue.fromMap('one', {...data, 'latitude': double.nan}),
      isNull,
    );
    expect(TrailIssue.fromMap('one', {...data, 'longitude': 190}), isNull);
  });
  testWidgets('issue description closes when the live notice is removed', (
    tester,
  ) async {
    final updates = StreamController<List<TrailIssue>>();
    addTearDown(updates.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trailIssuesProvider(
            'cyprus-e4',
          ).overrideWith((ref) => updates.stream),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const TrailIssueSheet(
                    trailId: 'cyprus-e4',
                    issueId: 'approved',
                  ),
                ),
                child: const Text('Open issue'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open issue'));
    await tester.pump();
    updates.add([issue]);
    await tester.pumpAndSettle();
    expect(find.text(issue.description), findsOneWidget);
    updates.add([]);
    await tester.pumpAndSettle();
    expect(find.byType(TrailIssueSheet), findsNothing);
  });
}
