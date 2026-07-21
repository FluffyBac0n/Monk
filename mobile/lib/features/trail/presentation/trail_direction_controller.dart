import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trail_direction.dart';

final trailDirectionProvider =
    NotifierProvider<TrailDirectionController, TrailDirection>(
      TrailDirectionController.new,
    );

class TrailDirectionController extends Notifier<TrailDirection> {
  @override
  TrailDirection build() => TrailDirection.pafosToLarnaka;

  void toggle() {
    state = state.isReversed
        ? TrailDirection.pafosToLarnaka
        : TrailDirection.larnakaToPafos;
  }
}
