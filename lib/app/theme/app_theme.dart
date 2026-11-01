import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(Brightness brightness, Color accent) {
    final dark = brightness == Brightness.dark;
    final primary = dark
        ? accent
        : HSLColor.fromColor(
            accent,
          ).withLightness(0.30).withSaturation(0.75).toColor();

    // Selected segments, chips and default progress tracks come from the *container*
    // colors. Left unset they fall back to `secondary` (a fixed cyan), which made them
    // ignore the accent and, on progress bars, look like a second filled bar.
    final accentContainer = Color.alphaBlend(
      primary.withValues(alpha: dark ? 0.30 : 0.22),
      dark ? AppColors.surface3 : AppColors.paper3,
    );
    final onAccentContainer = dark ? AppColors.text : AppColors.inkLight;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? AppColors.obsidian : Colors.white,
      secondary: dark ? AppColors.cyan : const Color(0xFF0E7490),
      onSecondary: dark ? AppColors.obsidian : Colors.white,
      tertiary: dark ? AppColors.amber : const Color(0xFF9A6700),
      onTertiary: dark ? AppColors.obsidian : Colors.white,
      error: dark ? AppColors.danger : const Color(0xFFB42318),
      onError: dark ? AppColors.obsidian : Colors.white,
      primaryContainer: accentContainer,
      onPrimaryContainer: onAccentContainer,
      secondaryContainer: accentContainer,
      onSecondaryContainer: onAccentContainer,
      surface: dark ? AppColors.obsidian : AppColors.paper,
      onSurface: dark ? AppColors.text : AppColors.inkLight,
      onSurfaceVariant: dark ? AppColors.textDim : AppColors.inkLightDim,
      surfaceContainerLowest: dark ? const Color(0xFF070A0D) : AppColors.paper1,
      surfaceContainerLow: dark ? AppColors.surface1 : AppColors.paper1,
      surfaceContainer: dark ? AppColors.surface2 : AppColors.paper2,
      surfaceContainerHigh: dark ? AppColors.surface3 : AppColors.paper3,
      surfaceContainerHighest: dark ? AppColors.line : AppColors.paperLine,
      outline: dark ? AppColors.textDim : AppColors.inkLightDim,
      outlineVariant: dark ? AppColors.line : AppColors.paperLine,
    );

    final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final textTheme = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w500),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, letterSpacing: 0.4, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Monospace label style used for the "instrument readout" look.
TextStyle readoutStyle(BuildContext context, {Color? color, double size = 11}) {
  final scheme = Theme.of(context).colorScheme;
  return TextStyle(
    fontFamily: 'monospace',
    fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier New'],
    fontSize: size,
    letterSpacing: 1.4,
    fontWeight: FontWeight.w500,
    color: color ?? scheme.onSurfaceVariant,
  );
}
