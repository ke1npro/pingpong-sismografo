import 'package:flutter/material.dart';

/// Centralized Design System Colors for Neon Motion Arcade.
///
/// Features deep void space backgrounds, high-contrast text,
/// and 5 distinct cyber neon accent colors.
class ArcadeColors {
  ArcadeColors._();

  // Void & Space Backgrounds
  static const Color spaceVoid = Color(0xFF05050A);
  static const Color spaceBackground = Color(0xFF0A0E17);
  static const Color surfaceDark = Color(0xFF101624);
  static const Color surfaceElevated = Color(0xFF172033);
  static const Color surfaceGlass = Color(0xB3101624);
  static const Color borderSubtle = Color(0x334A6B8A);

  // Cyber Neon Spectrum
  static const Color neonCyan = Color(0xFF00F0FF);
  static const Color neonMagenta = Color(0xFFFF007F);
  static const Color neonPurple = Color(0xFFB026FF);
  static const Color neonLime = Color(0xFF00FF66);
  static const Color neonAmber = Color(0xFFFFD600);
  static const Color neonRed = Color(0xFFFF1744);

  // High Contrast Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF475569);
}

/// Multi-tier neon glow and dark elevation utilities.
class ArcadeShadows {
  ArcadeShadows._();

  /// Creates a multi-layer neon glow effect using two blurred shadows.
  static List<BoxShadow> neonGlow(Color color, {double intensity = 1.0}) {
    final clamped = intensity.clamp(0.0, 2.0);
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35 * clamped),
        blurRadius: 12.0,
        spreadRadius: 1.0,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.18 * clamped),
        blurRadius: 4.0,
        spreadRadius: 0.0,
      ),
    ];
  }

  /// Subtle glow for micro-elements, pills, and indicators.
  static List<BoxShadow> softGlow(Color color, {double intensity = 1.0}) {
    final clamped = intensity.clamp(0.0, 2.0);
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.22 * clamped),
        blurRadius: 8.0,
        spreadRadius: 0.5,
      ),
    ];
  }

  /// Dark depth elevation shadow for cards and panels.
  static List<BoxShadow> cardElevation() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.65),
        blurRadius: 10.0,
        offset: const Offset(0, 4),
      ),
    ];
  }
}

/// Centralized Typography tokens for headers, tabular figures, and telemetry.
class ArcadeTypography {
  ArcadeTypography._();

  /// Bold display header with wide tracking for arcade titles.
  static const TextStyle headerDisplay = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: 2.0,
    color: ArcadeColors.textPrimary,
  );

  /// Sub-header for card titles and section banners.
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    color: ArcadeColors.textPrimary,
  );

  /// Tabular monospace digits for scores and dynamic game metrics.
  static const TextStyle hudNumber = TextStyle(
    fontFamily: 'monospace',
    fontSize: 18,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ArcadeColors.neonAmber,
  );

  /// Compact tabular monospace numbers for sensor axes and small readouts.
  static const TextStyle hudNumberSmall = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ArcadeColors.textPrimary,
  );

  /// Micro telemetry label for axis tags, units, and captions.
  static const TextStyle microLabel = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 9.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: ArcadeColors.textSecondary,
  );

  /// Standard readable body text.
  static const TextStyle bodyText = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 13,
    color: ArcadeColors.textSecondary,
  );

  /// Generates a styled text style with optional neon drop glow.
  static TextStyle neonText({
    required Color color,
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.bold,
    double letterSpacing = 1.0,
    bool isMonospace = false,
    bool withGlow = true,
  }) {
    return TextStyle(
      fontFamily: isMonospace ? 'monospace' : 'Roboto',
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: isMonospace ? const [FontFeature.tabularFigures()] : null,
      shadows: withGlow
          ? [
              Shadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 8.0,
              ),
            ]
          : null,
    );
  }
}

/// Dark Material 3 theme applying all dark-arcade design tokens.
final ThemeData arcadeThemeData = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: ArcadeColors.spaceBackground,
  canvasColor: ArcadeColors.spaceVoid,
  cardColor: ArcadeColors.surfaceDark,
  colorScheme: const ColorScheme.dark(
    primary: ArcadeColors.neonCyan,
    onPrimary: ArcadeColors.spaceVoid,
    secondary: ArcadeColors.neonMagenta,
    onSecondary: ArcadeColors.spaceVoid,
    tertiary: ArcadeColors.neonPurple,
    onTertiary: ArcadeColors.spaceVoid,
    surface: ArcadeColors.surfaceDark,
    onSurface: ArcadeColors.textPrimary,
    error: ArcadeColors.neonRed,
    onError: ArcadeColors.textPrimary,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: ArcadeColors.surfaceDark,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: ArcadeTypography.headerDisplay,
    iconTheme: IconThemeData(color: ArcadeColors.neonCyan),
  ),
  cardTheme: CardThemeData(
    color: ArcadeColors.surfaceDark,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: ArcadeColors.borderSubtle, width: 1.0),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 60,
    backgroundColor: ArcadeColors.surfaceDark,
    indicatorColor: ArcadeColors.surfaceElevated,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: ArcadeColors.textPrimary,
        );
      }
      return const TextStyle(
        fontSize: 11,
        color: ArcadeColors.textSecondary,
      );
    }),
  ),
  sliderTheme: SliderThemeData(
    trackHeight: 4,
    activeTrackColor: ArcadeColors.neonLime,
    inactiveTrackColor: ArcadeColors.surfaceElevated,
    thumbColor: ArcadeColors.neonLime,
    overlayColor: ArcadeColors.neonLime.withValues(alpha: 0.2),
    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: ArcadeColors.surfaceDark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: ArcadeColors.neonCyan, width: 1.2),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: ArcadeColors.surfaceElevated,
    contentTextStyle: ArcadeTypography.bodyText,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      side: BorderSide(color: ArcadeColors.neonCyan, width: 0.8),
    ),
  ),
  textTheme: const TextTheme(
    displayLarge: ArcadeTypography.headerDisplay,
    titleMedium: ArcadeTypography.sectionTitle,
    bodyMedium: ArcadeTypography.bodyText,
    labelSmall: ArcadeTypography.microLabel,
  ),
);

/// Convenience namespace class for Arcade theme.
class ArcadeTheme {
  ArcadeTheme._();
  static ThemeData get themeData => arcadeThemeData;
}
