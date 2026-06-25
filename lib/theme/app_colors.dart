import 'package:flutter/material.dart';

/// The single source of truth for every color in the app.
///
/// All UI colors live here as two ready-made palettes — [AppColors.light] and
/// [AppColors.dark]. To re-skin the app, edit the values in one of these two
/// instances; nothing else hard-codes a color.
///
/// It is wired in as a [ThemeExtension] so any widget can read the active
/// palette with `Theme.of(context).colors` (see [AppColorsX]); switching the
/// app's [ThemeMode] swaps the whole object automatically.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.gradientTop,
    required this.gradientCenter,
    required this.gradientBottom,
    required this.surface,
    required this.surfaceBorder,
    required this.shadow,
    required this.accent,
    required this.accentSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.chartBar,
    required this.chartBarSelected,
    required this.chartTrack,
  });

  /// Used to derive the Material [ColorScheme] brightness.
  final Brightness brightness;

  // Background gradient (top edge -> center -> bottom edge).
  final Color gradientTop;
  final Color gradientCenter;
  final Color gradientBottom;

  // Cards / elevated surfaces.
  final Color surface;
  final Color surfaceBorder;
  final Color shadow;

  // Brand accent (the "pointe de violet").
  final Color accent;
  final Color accentSoft;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color divider;

  // Chart.
  final Color chartBar;
  final Color chartBarSelected;
  final Color chartTrack;

  /// Light palette: airy white center with a barely-there violet/blue wash at
  /// the top and bottom edges, sober text, soft violet accent.
  static const AppColors light = AppColors(
    brightness: Brightness.light,
    gradientTop: Color(0xFFF1EFFB),
    gradientCenter: Color(0xFFFFFFFF),
    gradientBottom: Color(0xFFEDEFFB),
    surface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0xFFECEAF3),
    shadow: Color(0x171A1730),
    accent: Color(0xFF7C6BF0),
    accentSoft: Color(0xFFECE9FD),
    textPrimary: Color(0xFF1C1B22),
    textSecondary: Color(0xFF6B6A78),
    textMuted: Color(0xFF9A99A8),
    divider: Color(0xFFEEEDF3),
    chartBar: Color(0xFFDAD5F6),
    chartBarSelected: Color(0xFF7C6BF0),
    chartTrack: Color(0xFFF3F2F8),
  );

  /// Dark palette: deep near-black with a faint violet cast, lighter violet
  /// accent for contrast.
  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    gradientTop: Color(0xFF1B1828),
    gradientCenter: Color(0xFF121017),
    gradientBottom: Color(0xFF181624),
    surface: Color(0xFF1C1A26),
    surfaceBorder: Color(0xFF2B2838),
    shadow: Color(0x66000000),
    accent: Color(0xFF9D8DF5),
    accentSoft: Color(0xFF2A2640),
    textPrimary: Color(0xFFF4F3F8),
    textSecondary: Color(0xFFB0AEC0),
    textMuted: Color(0xFF76747F),
    divider: Color(0xFF262430),
    chartBar: Color(0xFF332F4A),
    chartBarSelected: Color(0xFF9D8DF5),
    chartTrack: Color(0xFF1F1D2B),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? gradientTop,
    Color? gradientCenter,
    Color? gradientBottom,
    Color? surface,
    Color? surfaceBorder,
    Color? shadow,
    Color? accent,
    Color? accentSoft,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? chartBar,
    Color? chartBarSelected,
    Color? chartTrack,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      gradientTop: gradientTop ?? this.gradientTop,
      gradientCenter: gradientCenter ?? this.gradientCenter,
      gradientBottom: gradientBottom ?? this.gradientBottom,
      surface: surface ?? this.surface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      shadow: shadow ?? this.shadow,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      chartBar: chartBar ?? this.chartBar,
      chartBarSelected: chartBarSelected ?? this.chartBarSelected,
      chartTrack: chartTrack ?? this.chartTrack,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      gradientTop: Color.lerp(gradientTop, other.gradientTop, t)!,
      gradientCenter: Color.lerp(gradientCenter, other.gradientCenter, t)!,
      gradientBottom: Color.lerp(gradientBottom, other.gradientBottom, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chartBar: Color.lerp(chartBar, other.chartBar, t)!,
      chartBarSelected: Color.lerp(
        chartBarSelected,
        other.chartBarSelected,
        t,
      )!,
      chartTrack: Color.lerp(chartTrack, other.chartTrack, t)!,
    );
  }
}

/// Convenience accessor so widgets can write `Theme.of(context).colors`.
extension AppColorsX on ThemeData {
  AppColors get colors => extension<AppColors>()!;
}
