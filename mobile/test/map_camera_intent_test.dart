import 'dart:async';

import 'package:eurotrex/features/map/domain/map_camera_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zoom before map loading finishes prevents the initial route fit', () {
    final camera = MapCameraIntent();
    camera.onGesture();

    expect(camera.initialRequest, isNull);
  });

  test(
    'zoom while bounds are being calculated cancels the pending fit',
    () async {
      final camera = MapCameraIntent();
      final request = camera.initialRequest;
      final bounds = Completer<void>();
      var applied = false;
      final fit = bounds.future.then((_) {
        if (camera.isCurrent(request)) applied = true;
      });

      camera.onGesture();
      bounds.complete();
      await fit;

      expect(applied, isFalse);
      expect(camera.initialRequest, isNull);
    },
  );

  test('browsing the map stops GPS following, including delayed fixes', () {
    final camera = MapCameraIntent()..startLocation(focus: true);
    final pendingFix = camera.revision;
    expect(camera.shouldFollowLocation(pendingFix), isTrue);

    camera.onGesture();

    expect(camera.shouldFollowLocation(pendingFix), isFalse);
    expect(camera.shouldFollowLocation(camera.revision), isFalse);
  });

  test('stage location tracking never takes over the camera', () {
    final camera = MapCameraIntent()..startLocation(focus: false);

    expect(camera.shouldFollowLocation(camera.revision), isFalse);
    expect(camera.initialRequest, isNotNull);
  });

  test(
    'explicitly locating again resumes follow without reviving old work',
    () {
      final camera = MapCameraIntent()..startLocation(focus: true);
      final oldFix = camera.revision;
      camera.onGesture();
      camera.stopLocation();
      camera.startLocation(focus: true);

      expect(camera.shouldFollowLocation(oldFix), isFalse);
      expect(camera.shouldFollowLocation(camera.revision), isTrue);
      expect(camera.initialRequest, isNull);
    },
  );

  test('a location action supersedes a pending initial camera fit', () {
    final camera = MapCameraIntent();
    final fitRequest = camera.initialRequest;
    camera.startLocation(focus: true);

    expect(camera.isCurrent(fitRequest), isFalse);
    expect(camera.initialRequest, isNull);
    camera.stopLocation();
    expect(camera.shouldFollowLocation(camera.revision), isFalse);
  });
}
