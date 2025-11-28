import 'package:flutter/material.dart';
import 'eve_colors.dart';

/// Application theme configuration using Material Design 3.
abstract class AppTheme {
  /// Creates the dark theme for the application.
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.dark(
      primary: EveColors.evePrimary,
      onPrimary: Colors.white,
      secondary: EveColors.eveSecondary,
      onSecondary: Colors.black,
      tertiary: EveColors.eveTertiary,
      onTertiary: Colors.white,
      surface: EveColors.darkSurface,
      onSurface: Colors.white,
      error: EveColors.error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: EveColors.darkBackground,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: EveColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: EveColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Bottom navigation theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: EveColors.darkSurface,
        selectedItemColor: EveColors.evePrimary,
        unselectedItemColor: Colors.white54,
      ),

      // Navigation rail theme (for desktop)
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: EveColors.darkSurface,
        selectedIconTheme: const IconThemeData(color: EveColors.evePrimary),
        unselectedIconTheme: const IconThemeData(color: Colors.white54),
        indicatorColor: EveColors.evePrimary.withAlpha(51),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: EveColors.darkSurfaceVariant,
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

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EveColors.evePrimary,
        ),
      ),

      // Divider theme
      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 1,
      ),

      // List tile theme
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: EveColors.darkSurfaceVariant,
        labelStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EveColors.evePrimary,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: EveColors.darkSurfaceElevated,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: EveColors.darkSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
