import 'package:flutter/material.dart';

/// The "Night neon" palette, from the design canvas.
///
/// Widgets never use these directly: they read the colour scheme built from
/// them ([AppColors.scheme]), through `Theme.of(context).colorScheme`.
abstract final class AppColors {
  /// Background of every screen: a deep violet, never pure black.
  static const Color night = Color(0xFF0D0A18);

  /// Cards, sheets and dialogs.
  static const Color surface = Color(0xFF18132B);

  /// Fields and raised elements.
  static const Color raised = Color(0xFF241D3F);

  /// Light text on the night background.
  static const Color text = Color(0xFFF4F1FF);

  /// Secondary text.
  static const Color mist = Color(0xFFA79FC6);

  /// What happens in real life: crossings, meetups, main actions. One
  /// Signal action per screen at most.
  static const Color signal = Color(0xFFC6F432);

  /// Groups, events and links between people.
  static const Color aura = Color(0xFFA98BFF);

  /// Borders.
  static const Color line = Color(0xFF3A3260);

  /// Errors and actions that cannot be undone.
  static const Color danger = Color(0xFFFF8A7A);

  static const ColorScheme scheme = ColorScheme(
    brightness: Brightness.dark,
    primary: signal,
    onPrimary: night,
    primaryContainer: Color(0xFF2E3812),
    onPrimaryContainer: Color(0xFFE2FF8A),
    secondary: aura,
    onSecondary: night,
    secondaryContainer: Color(0xFF3A2E6B),
    onSecondaryContainer: Color(0xFFEDE6FF),
    tertiary: aura,
    onTertiary: night,
    tertiaryContainer: Color(0xFF3A2E6B),
    onTertiaryContainer: Color(0xFFEDE6FF),
    error: danger,
    onError: night,
    errorContainer: Color(0xFF5C1F1A),
    onErrorContainer: Color(0xFFFFDAD4),
    surface: night,
    onSurface: text,
    onSurfaceVariant: mist,
    surfaceDim: night,
    surfaceBright: Color(0xFF2B2448),
    surfaceContainerLowest: Color(0xFF09070F),
    surfaceContainerLow: Color(0xFF130F22),
    surfaceContainer: surface,
    surfaceContainerHigh: Color(0xFF1E1835),
    surfaceContainerHighest: raised,
    outline: line,
    outlineVariant: Color(0xFF2B2448),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: text,
    onInverseSurface: night,
    inversePrimary: Color(0xFF4A5E00),
    surfaceTint: Color(0x00000000),
  );
}

/// Corner radii: very rounded, as in the design canvas.
abstract final class AppRadii {
  /// Carousel pages and large cards.
  static const double card = 28;

  /// Dialogs and bottom sheets.
  static const double sheet = 28;

  /// Text fields and small cards.
  static const double field = 18;

  /// Thumbnails in the page editing mode.
  static const double thumbnail = 16;
}
