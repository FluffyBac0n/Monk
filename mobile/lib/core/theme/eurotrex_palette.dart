import 'package:flutter/material.dart';

abstract final class EurotrexPalette {
  static const navy = Color(0xFF303E4E);
  static const blue = Color(0xFF2D5DD3);
  static const paleBlue = Color(0xFFE2EBEE);

  static ThemeData controlsTheme(ThemeData base) {
    final colorScheme = base.colorScheme.copyWith(
      primary: blue,
      onPrimary: Colors.white,
      primaryContainer: paleBlue,
      onPrimaryContainer: navy,
      secondary: blue,
      secondaryContainer: paleBlue,
      onSecondaryContainer: navy,
    );
    return base.copyWith(
      colorScheme: colorScheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paleBlue.withValues(alpha: 0.42),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: paleBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: paleBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: paleBlue,
        checkmarkColor: blue,
        side: const BorderSide(color: paleBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          side: BorderSide(color: blue.withValues(alpha: 0.65)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? paleBlue : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? blue : navy,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.selected) ? blue : paleBlue,
            ),
          ),
        ),
      ),
    );
  }
}
