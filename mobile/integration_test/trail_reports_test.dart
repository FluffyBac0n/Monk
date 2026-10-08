import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:eurotrex/core/database/app_database.dart';
import 'package:eurotrex/features/reports/data/report_photos.dart';
import 'package:eurotrex/features/reports/data/report_store.dart';
import 'package:eurotrex/features/reports/data/report_sync.dart';
import 'package:eurotrex/features/reports/presentation/report_screen.dart';
import 'package:eurotrex/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native report: validation, durable photo draft, queued upload and receipt',
    (tester) async {
      final host = Platform.isAndroid ? '10.0.2.2' : '127.0.0.1';
      final native = DefaultFirebaseOptions.currentPlatform;
      final app = await Firebase.initializeApp(
        name: 'trail-reports-emulator',
        options: FirebaseOptions(
          apiKey: native.apiKey,
          appId: native.appId,
          messagingSenderId: native.messagingSenderId,
          projectId: 'demo-eurotrex',
          storageBucket: 'demo-eurotrex.appspot.com',
          iosBundleId: native.iosBundleId,
        ),
      );
      await FirebaseAuth.instanceFor(app: app).useAuthEmulator(host, 9099);
      FirebaseFunctions.instanceFor(
        app: app,
        region: 'europe-west1',
      ).useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instanceFor(
        app: app,
      ).useStorageEmulator(host, 9199);
      await FirebaseAuth.instanceFor(app: app).signOut();
      await FirebaseAuth.instanceFor(app: app).signInAnonymously();
      final store = ReportStore(AppDatabase());
      final draft = ReportDraft(
        id: const Uuid().v4(),
        trailId: 'cyprus-e4',
        createdAt: DateTime.now().toUtc(),
        latitude: 34.89,
        longitude: 32.87,
      );
      final temp = File(
        '${(await getTemporaryDirectory()).path}/report-test.jpg',
      );
      await temp.writeAsBytes(img.encodeJpg(img.Image(width: 64, height: 64)));
      draft.photos = [await importReportPhoto(XFile(temp.path), draft.id)];
      await store.save(draft);
      final offline = ReportSync(store, enabled: false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reportStoreProvider.overrideWithValue(store),
            reportSyncProvider.overrideWithValue(offline),
          ],
          child: MaterialApp(
            home: ReportScreen(trailId: draft.trailId, draft: draft),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Send report'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Add a description, choose a location, and check the optional email.',
        ),
        findsOneWidget,
      );
      final description = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'What is the problem?',
      );
      await tester.scrollUntilVisible(
        description,
        -350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(description, 'SIMULATOR TEST: damaged signpost');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(draft.description, 'SIMULATOR TEST: damaged signpost');
      expect(draft.contactEmail, isEmpty);
      await tester.scrollUntilVisible(
        find.text('Send report'),
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      // Native PackageInfo/SQLite work may complete after the route animation
      // settles on iOS. Wait for the actual receipt screen, not just animations.
      for (
        var i = 0;
        i < 100 && find.text('My reports').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('My reports'), findsOneWidget);
      final restored = (await ReportStore(
        AppDatabase(),
      ).all()).firstWhere((d) => d.id == draft.id);
      expect(restored.state, 'queued');
      expect(restored.trailId, 'cyprus-e4');
      expect(await File(restored.photos.single).exists(), isTrue);
      expect(restored.locationConfirmed, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      offline.dispose();
      final online = ReportSync(store, enabled: true, firebaseApp: app);
      ReportDraft received = restored;
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(seconds: 1));
        received = (await store.all()).firstWhere((d) => d.id == draft.id);
        if (received.state == 'sent' || received.state == 'failed') break;
      }
      expect(received.state, 'sent', reason: received.error);
      await online.refreshReceipt(received);
      expect(received.remoteStatus, 'new');
      online.dispose();
      await store.remove(received);
      await temp.delete();
    },
  );
}
