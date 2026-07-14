import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  const AppTheme._();

  static const _seed = Color(0xFF0F6E5C);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light);
    final baseTextTheme = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;
    // Operators read this in the field, often at a glance — bump the whole
    // type scale up rather than enlarging individual widgets piecemeal.
    // Scaled by hand (not TextTheme.apply) since a couple of M3 default
    // slots ship with a null fontSize, which apply's fontSizeFactor rejects.
    final textTheme = _scaleTextTheme(baseTextTheme, 1.2);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerLow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  static TextTheme _scaleTextTheme(TextTheme base, double factor) {
    TextStyle? scale(TextStyle? style) =>
        (style == null || style.fontSize == null) ? style : style.copyWith(fontSize: style.fontSize! * factor);

    return base.copyWith(
      displayLarge: scale(base.displayLarge),
      displayMedium: scale(base.displayMedium),
      displaySmall: scale(base.displaySmall),
      headlineLarge: scale(base.headlineLarge),
      headlineMedium: scale(base.headlineMedium),
      headlineSmall: scale(base.headlineSmall),
      titleLarge: scale(base.titleLarge),
      titleMedium: scale(base.titleMedium),
      titleSmall: scale(base.titleSmall),
      bodyLarge: scale(base.bodyLarge),
      bodyMedium: scale(base.bodyMedium),
      bodySmall: scale(base.bodySmall),
      labelLarge: scale(base.labelLarge),
      labelMedium: scale(base.labelMedium),
      labelSmall: scale(base.labelSmall),
    );
  }
}
