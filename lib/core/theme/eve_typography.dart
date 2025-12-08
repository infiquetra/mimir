import 'package:flutter/material.dart';

/// EVE Online Photon UI typography system.
///
/// Uses a combination of bundled fonts to recreate the EVE aesthetic:
/// - Orbitron: Display/headings (geometric, futuristic like Shentox)
/// - K2D: Body text (clean, readable geometric sans)
/// - JetBrains Mono: Data/numbers (monospace for alignment)
///
/// Fonts are bundled in assets/fonts/ to avoid runtime fetching issues
/// in multi-window environments.
abstract class EveTypography {
  // ==========================================================================
  // Font Families
  // ==========================================================================

  /// Display font for major headings (Orbitron - similar to EVE's Shentox).
  static const String displayFont = 'Orbitron';

  /// Body font for general text (K2D - clean geometric sans).
  static const String bodyFont = 'K2D';

  /// Monospace font for data and numbers (JetBrains Mono).
  static const String monoFont = 'JetBrainsMono';

  // ==========================================================================
  // Font Weights
  // ==========================================================================

  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // ==========================================================================
  // Display Styles (Orbitron - Screen titles, major headings)
  // ==========================================================================

  /// Display text (24px) - Screen titles.
  static TextStyle display({Color? color}) => TextStyle(
        fontFamily: displayFont,
        fontSize: 24,
        fontWeight: bold,
        color: color,
        letterSpacing: 0.5,
      );

  /// Display medium (20px) - Sub-headings.
  static TextStyle displayMedium({Color? color}) => TextStyle(
        fontFamily: displayFont,
        fontSize: 20,
        fontWeight: semiBold,
        color: color,
        letterSpacing: 0.5,
      );

  // ==========================================================================
  // Headline Styles (Orbitron - Section headers)
  // ==========================================================================

  /// Headline text (18px) - Section headers.
  static TextStyle headline({Color? color}) => TextStyle(
        fontFamily: displayFont,
        fontSize: 18,
        fontWeight: semiBold,
        color: color,
        letterSpacing: 0.5,
      );

  /// Headline small (16px) - Minor headings.
  static TextStyle headlineSmall({Color? color}) => TextStyle(
        fontFamily: displayFont,
        fontSize: 16,
        fontWeight: medium,
        color: color,
        letterSpacing: 0.3,
      );

  // ==========================================================================
  // Title Styles (K2D - Card titles, labels)
  // ==========================================================================

  /// Title large (14px bold) - Card titles, important labels.
  static TextStyle titleLarge({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: semiBold,
        color: color,
      );

  /// Title medium (14px regular) - Standard titles.
  static TextStyle titleMedium({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 14,
        fontWeight: medium,
        color: color,
      );

  /// Title small (13px) - Compact titles.
  static TextStyle titleSmall({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 13,
        fontWeight: medium,
        color: color,
      );

  // ==========================================================================
  // Body Styles (K2D - Primary content)
  // ==========================================================================

  /// Body large (13px) - Primary content.
  static TextStyle bodyLarge({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 13,
        fontWeight: regular,
        color: color,
      );

  /// Body medium (12px) - Standard body text.
  static TextStyle bodyMedium({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 12,
        fontWeight: regular,
        color: color,
      );

  /// Body small (11px) - Compact body text.
  static TextStyle bodySmall({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: regular,
        color: color,
      );

  // ==========================================================================
  // Label Styles (K2D - Labels, metadata)
  // ==========================================================================

  /// Label large (11px) - Standard labels.
  static TextStyle labelLarge({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 11,
        fontWeight: medium,
        color: color,
      );

  /// Label medium (10px) - Compact labels.
  static TextStyle labelMedium({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 10,
        fontWeight: medium,
        color: color,
      );

  /// Label small (9px) - Timestamps, micro labels.
  static TextStyle labelSmall({Color? color}) => TextStyle(
        fontFamily: bodyFont,
        fontSize: 9,
        fontWeight: regular,
        color: color,
      );

  // ==========================================================================
  // Data Styles (JetBrains Mono - Numbers, technical data)
  // ==========================================================================

  /// Data large (14px) - Featured numbers (ISK balances, etc).
  static TextStyle dataLarge({Color? color}) => TextStyle(
        fontFamily: monoFont,
        fontSize: 14,
        fontWeight: bold,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Data medium (12px) - Standard data display.
  static TextStyle dataMedium({Color? color}) => TextStyle(
        fontFamily: monoFont,
        fontSize: 12,
        fontWeight: medium,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Data small (11px) - Compact data tables.
  static TextStyle dataSmall({Color? color}) => TextStyle(
        fontFamily: monoFont,
        fontSize: 11,
        fontWeight: regular,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Creates a TextTheme for Material 3 using our custom fonts.
  static TextTheme createTextTheme({required ColorScheme colorScheme}) {
    final color = colorScheme.onSurface;

    return TextTheme(
      // Display
      displayLarge: display(color: color),
      displayMedium: displayMedium(color: color),
      displaySmall: headline(color: color),

      // Headline
      headlineLarge: headline(color: color),
      headlineMedium: headline(color: color),
      headlineSmall: headlineSmall(color: color),

      // Title
      titleLarge: titleLarge(color: color),
      titleMedium: titleMedium(color: color),
      titleSmall: titleSmall(color: color),

      // Body
      bodyLarge: bodyLarge(color: color),
      bodyMedium: bodyMedium(color: color),
      bodySmall: bodySmall(color: color),

      // Label
      labelLarge: labelLarge(color: color),
      labelMedium: labelMedium(color: color),
      labelSmall: labelSmall(color: color),
    );
  }
}
