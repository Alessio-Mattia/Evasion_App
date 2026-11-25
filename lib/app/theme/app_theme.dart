import 'package:evasion/app/theme/app_colors.dart';
import 'package:evasion/app/theme/app_fonts.dart';
import 'package:flutter/material.dart';

/// The "Night neon" theme: the only place where colours, fonts and shapes are
/// chosen. Screens read them through `Theme.of(context)`.
abstract final class AppTheme {
  static final ThemeData dark = _build();

  static ThemeData _build() {
    const scheme = AppColors.scheme;
    final base = ThemeData(
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: scheme.surface,
    );
    // ThemeData only adds the font sizes when a screen reads the theme: the
    // styles reused below (app bar, chips, tabs) need them from the start.
    final text = _textTheme(
      Typography.material2021().englishLike.merge(base.textTheme),
    );
    const pill = StadiumBorder();
    const buttonSize = Size(64, 52);
    final buttonText = text.labelLarge?.copyWith(fontSize: 16);

    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: pill,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: pill, textStyle: text.labelLarge),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide(color: scheme.outline),
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: _fieldBorder(BorderSide.none),
        enabledBorder: _fieldBorder(BorderSide.none),
        focusedBorder: _fieldBorder(
          BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: _fieldBorder(BorderSide(color: scheme.error)),
        focusedErrorBorder: _fieldBorder(
          BorderSide(color: scheme.error, width: 1.5),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // The selected tab is told by its Signal colour, not by a pill.
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sheet),
        ),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurface),
        actionTextColor: scheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    );
  }

  static OutlineInputBorder _fieldBorder(BorderSide side) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadii.field),
    borderSide: side,
  );

  /// Bricolage Grotesque for display, headlines and large titles, tight and
  /// bold; Inter for everything else.
  static TextTheme _textTheme(TextTheme base) {
    TextStyle? heading(TextStyle? style, FontWeight weight, double spacing) =>
        style?.copyWith(
          fontFamily: AppFonts.display,
          fontWeight: weight,
          letterSpacing: spacing,
        );

    return base.copyWith(
      displayLarge: heading(base.displayLarge, FontWeight.w800, -1.5),
      displayMedium: heading(base.displayMedium, FontWeight.w800, -1.2),
      displaySmall: heading(base.displaySmall, FontWeight.w800, -1),
      headlineLarge: heading(base.headlineLarge, FontWeight.w800, -0.8),
      headlineMedium: heading(base.headlineMedium, FontWeight.w800, -0.6),
      headlineSmall: heading(base.headlineSmall, FontWeight.w700, -0.4),
      titleLarge: heading(base.titleLarge, FontWeight.w700, -0.2),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
