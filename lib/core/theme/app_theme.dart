import 'package:flutter/material.dart';
import 'eve_colors.dart';
import 'eve_spacing.dart';
import 'eve_typography.dart';

/// Application theme configuration using Material Design 3 and Photon Dark.
abstract class AppTheme {
  /// Creates the dark theme for the application.
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.dark(
      primary: EveColors.photonBlue,
      onPrimary: Colors.white,
      secondary: EveColors.photonCyan,
      onSecondary: Colors.black,
      tertiary: EveColors.photonHighlight,
      onTertiary: Colors.white,
      surface: EveColors.surfaceDefault,
      onSurface: EveColors.textPrimary,
      error: EveColors.error,
      onError: Colors.white,
      outline: EveColors.borderSubtle,
      outlineVariant: EveColors.borderActive,
    );

    // Create custom text theme
    final textTheme = EveTypography.createTextTheme(colorScheme: colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EveColors.backgroundBase,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: EveColors.surfaceDefault,
        foregroundColor: EveColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: EveTypography.displayMedium(
          color: EveColors.textPrimary,
        ),
      ),

      // Card theme (sharper radius, tighter spacing)
      cardTheme: CardThemeData(
        color: EveColors.surfaceDefault,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EveSpacing.cardRadius),
        ),
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EveColors.surfaceDefault,
        selectedItemColor: EveColors.photonBlue,
        unselectedItemColor: EveColors.textSecondary,
        selectedLabelStyle: EveTypography.labelSmall(),
        unselectedLabelStyle: EveTypography.labelSmall(),
      ),

      // Navigation rail theme (for desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: EveColors.surfaceDefault,
        selectedIconTheme: IconThemeData(
          color: EveColors.photonBlue,
          size: EveSpacing.iconMd,
        ),
        unselectedIconTheme: IconThemeData(
          color: EveColors.textSecondary,
          size: EveSpacing.iconMd,
        ),
        indicatorColor: EveColors.photonBlue.withAlpha(51),
        labelType: NavigationRailLabelType.all,
        selectedLabelTextStyle: EveTypography.labelMedium(
          color: EveColors.photonBlue,
        ),
        unselectedLabelTextStyle: EveTypography.labelMedium(
          color: EveColors.textSecondary,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EveColors.surfaceBright,
        contentPadding: EdgeInsets.symmetric(
          horizontal: EveSpacing.lg,
          vertical: EveSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EveSpacing.inputRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(EveSpacing.inputRadius),
          borderSide: const BorderSide(color: EveColors.photonBlue, width: 2),
        ),
        labelStyle: EveTypography.bodyMedium(color: EveColors.textSecondary),
        hintStyle: EveTypography.bodyMedium(color: EveColors.textTertiary),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EveColors.photonBlue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: EveSpacing.buttonPaddingH,
            vertical: EveSpacing.buttonPaddingV,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(EveSpacing.buttonRadius),
          ),
          textStyle: EveTypography.labelLarge(color: Colors.white),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EveColors.photonBlue,
          textStyle: EveTypography.labelLarge(color: EveColors.photonBlue),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: EveColors.divider,
        thickness: 1,
        space: EveSpacing.md,
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        iconColor: EveColors.textSecondary,
        textColor: EveColors.textPrimary,
        titleTextStyle: EveTypography.bodyMedium(color: EveColors.textPrimary),
        subtitleTextStyle: EveTypography.bodySmall(
          color: EveColors.textSecondary,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: EveSpacing.lg,
          vertical: EveSpacing.sm,
        ),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: EveColors.surfaceBright,
        labelStyle: EveTypography.labelMedium(color: EveColors.textPrimary),
        padding: EdgeInsets.symmetric(
          horizontal: EveSpacing.chipPaddingH,
          vertical: EveSpacing.chipPaddingV,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EveSpacing.chipRadius),
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EveColors.photonBlue,
        circularTrackColor: EveColors.borderSubtle,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EveColors.surfaceElevated,
        contentTextStyle: EveTypography.bodyMedium(
          color: EveColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EveSpacing.buttonRadius),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: EveColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EveSpacing.dialogRadius),
        ),
        titleTextStyle: EveTypography.headline(color: EveColors.textPrimary),
        contentTextStyle: EveTypography.bodyMedium(
          color: EveColors.textSecondary,
        ),
      ),

      // Tooltip theme
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: EveColors.surfaceElevated,
          borderRadius: BorderRadius.circular(EveSpacing.sm),
          border: Border.all(color: EveColors.borderSubtle),
        ),
        textStyle: EveTypography.labelSmall(color: EveColors.textPrimary),
        padding: EdgeInsets.all(EveSpacing.md),
      ),
    );
  }

  /// Creates the light theme for the application.
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.light(
      primary: EveColors.evePrimary,
      onPrimary: Colors.white,
      secondary: EveColors.eveSecondary,
      onSecondary: Colors.black,
      tertiary: EveColors.eveTertiary,
      onTertiary: Colors.white,
      surface: EveColors.lightSurface,
      onSurface: Colors.black87,
      error: EveColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      scaffoldBackgroundColor: EveColors.lightBackground,

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: EveColors.lightSurface,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: EveColors.lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: EveColors.lightSurface,
        selectedItemColor: EveColors.evePrimary,
        unselectedItemColor: Colors.black54,
      ),

      // Navigation rail theme (for desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: EveColors.lightSurface,
        selectedIconTheme: const IconThemeData(color: EveColors.evePrimary),
        unselectedIconTheme: const IconThemeData(color: Colors.black54),
        indicatorColor: EveColors.evePrimary.withAlpha(51),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EveColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: EveColors.evePrimary, width: 2),
        ),
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: EveColors.evePrimary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: Colors.black12,
        thickness: 1,
      ),
    );
  }
}
