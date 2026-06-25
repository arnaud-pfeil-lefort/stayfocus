import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] from an [AppColors] palette.
///
/// Everything visual flows from the palette + the Plus Jakarta Sans type
/// scale, so the two themes stay in sync by construction.
abstract final class AppTheme {
  static ThemeData light = _build(AppColors.light);
  static ThemeData dark = _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final base = ThemeData(brightness: c.brightness);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: c.brightness,
    ).copyWith(primary: c.accent, surface: c.surface, onSurface: c.textPrimary);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .apply(bodyColor: c.textPrimary, displayColor: c.textPrimary)
        .copyWith(
          // Slightly tighter, more "Apple" headings.
          headlineSmall: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: c.textPrimary,
          ),
          titleLarge: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: c.textPrimary,
          ),
          titleMedium: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: c.textPrimary,
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: c.textSecondary,
          ),
          labelSmall: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: c.textMuted,
          ),
        );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.gradientCenter,
      textTheme: textTheme,
      dividerColor: c.divider,
      splashFactory: InkRipple.splashFactory,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.accent,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
