import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eurotrex/core/theme/eurotrex_chrome_theme.dart';

void main() {
  test(
    'shared app chrome owns header and full-safe-area navigation styling',
    () {
      final appBar = EurotrexChromeTheme.appBar(title: const Text('Header'));
      final expandedHeader = appBar.flexibleSpace! as SizedBox;
      expect(expandedHeader.width, double.infinity);
      expect(expandedHeader.height, double.infinity);
      final headerSurface = expandedHeader.child! as DecoratedBox;
      final headerDecoration = headerSurface.decoration as BoxDecoration;
      expect(
        headerDecoration.gradient,
        same(EurotrexChromeTheme.navigationGradient),
      );

      final navigation = EurotrexChromeTheme.navigationBar(
        surfaceKey: const ValueKey('navigation'),
        contentKey: const ValueKey('navigation-content'),
        child: const SizedBox(),
      );
      final navigationSurface = navigation.child! as DecoratedBox;
      final navigationDecoration =
          navigationSurface.decoration as BoxDecoration;
      expect(
        navigationDecoration.gradient,
        same(EurotrexChromeTheme.navigationGradient),
      );
      expect(navigationSurface.child, isA<SafeArea>());
    },
  );
}
