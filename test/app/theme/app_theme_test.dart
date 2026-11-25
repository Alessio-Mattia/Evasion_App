import 'package:evasion/app/theme/app_fonts.dart';
import 'package:evasion/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrast ratio of two colours, as WCAG defines it: from 1 (same colour)
/// to 21 (black on white).
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (light, dark) = la > lb ? (la, lb) : (lb, la);
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  final theme = AppTheme.dark;
  final scheme = theme.colorScheme;

  test('the theme is dark', () {
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, scheme.surface);
  });

  group('text stays readable (WCAG AA, at least 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'text on the background': (scheme.onSurface, scheme.surface),
      'soft text on the background': (scheme.onSurfaceVariant, scheme.surface),
      'soft text on cards and fields': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainer,
      ),
      'text on raised elements': (
        scheme.onSurface,
        scheme.surfaceContainerHighest,
      ),
      'soft text on raised elements': (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
      ),
      'main buttons': (scheme.onPrimary, scheme.primary),
      'Signal links on the background': (scheme.primary, scheme.surface),
      'Signal links on cards': (scheme.primary, scheme.surfaceContainer),
      'Aura on the background': (scheme.secondary, scheme.surface),
      'selected chips': (
        scheme.onSecondaryContainer,
        scheme.secondaryContainer,
      ),
      'Signal containers': (scheme.onPrimaryContainer, scheme.primaryContainer),
      'errors on the background': (scheme.error, scheme.surface),
      'errors on cards': (scheme.error, scheme.surfaceContainer),
      'destructive buttons': (scheme.onError, scheme.error),
    };
    for (final MapEntry(key: name, value: (foreground, background))
        in pairs.entries) {
      test(name, () {
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
      });
    }
  });

  test('styles reused outside the text theme keep their size', () {
    // The app bar title used to fall back to 14 px.
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 22);
    expect(theme.chipTheme.labelStyle?.fontSize, 14);
  });

  test('headings use Bricolage Grotesque, the rest Inter', () {
    final text = theme.textTheme;
    for (final style in [
      text.displayLarge,
      text.headlineMedium,
      text.titleLarge,
    ]) {
      expect(style?.fontFamily, AppFonts.display);
    }
    for (final style in [
      text.titleMedium,
      text.bodyLarge,
      text.bodyMedium,
      text.labelLarge,
    ]) {
      expect(style?.fontFamily, AppFonts.body);
    }
  });
}
