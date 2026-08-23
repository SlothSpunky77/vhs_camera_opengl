import 'package:flutter/material.dart';

/// Palette and typography for the camcorder chrome.
///
/// Everything is drawn with system fonts so the app ships no asset payload.
abstract final class VhsTheme {
  static const Color background = Color(0xFF07090C);
  static const Color panel = Color(0xFF11151A);
  static const Color outline = Color(0xFF2A323B);
  static const Color osd = Color(0xFFEDEFE6);
  static const Color accent = Color(0xFF6DF0C2);
  static const Color record = Color(0xFFFF3B30);
  static const Color amber = Color(0xFFFFC845);

  static const List<String> _monoFallback = <String>[
    'Roboto Mono',
    'Courier New',
    'Courier',
  ];

  static TextStyle mono({
    double size = 12,
    FontWeight weight = FontWeight.w600,
    Color color = osd,
    double spacing = 1.4,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: _monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: spacing,
      height: 1.2,
    );
  }

  static ThemeData data() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(surface: background);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        activeTrackColor: accent,
        inactiveTrackColor: outline,
        thumbColor: accent,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      ),
    );
  }
}
