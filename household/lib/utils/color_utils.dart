import 'package:flutter/material.dart';

/// Parses a hex color string like "#ff9800" or "ff9800" or "#ccff9800" (with alpha).
/// Returns [fallback] on any parse failure.
Color hexColor(String hex, {Color fallback = const Color(0xFFFFF9C4)}) {
  try {
    final h = hex.trim().replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    if (h.length == 8) return Color(int.parse(h, radix: 16));
    return fallback;
  } catch (_) {
    return fallback;
  }
}

/// Returns the given color with lightness reduced by [amount] (0.0..1.0).
Color darken(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
