import 'package:flutter/material.dart';

import 'eurotrex_palette.dart';

abstract final class EurotrexChromeTheme {
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [EurotrexPalette.navy, EurotrexPalette.blue],
  );

  static const navigationGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF38516C), Color(0xFF2D619B)],
  );

  static AppBar appBar({
    Widget? title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    double? toolbarHeight,
  }) {
    return AppBar(
      backgroundColor: EurotrexPalette.navy,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: const SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: navigationGradient),
        ),
      ),
      title: title,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      toolbarHeight: toolbarHeight,
    );
  }

  static Material navigationBar({
    required Key surfaceKey,
    required Key contentKey,
    required Widget child,
    double height = 58,
  }) {
    return Material(
      key: surfaceKey,
      color: EurotrexPalette.navy,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: navigationGradient),
        child: SafeArea(
          top: false,
          child: Container(
            key: contentKey,
            height: height,
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
