import 'package:flutter/material.dart';

/// EVE Online inspired color palette.
///
/// These colors are designed to evoke the EVE Online aesthetic while
/// maintaining accessibility and Material Design 3 compatibility.
abstract class EveColors {
  // ==========================================================================
  // Primary Brand Colors
  // ==========================================================================

  /// EVE Blue - Primary brand color.
  static const Color evePrimary = Color(0xFF00A8FF);

  /// Teal accent - Secondary brand color.
  static const Color eveSecondary = Color(0xFF00D4AA);

  /// Tertiary accent for highlights.
  static const Color eveTertiary = Color(0xFFFF6B35);

  // ==========================================================================
  // Dark Theme Background Colors
  // ==========================================================================

  /// Deep space background.
  static const Color darkBackground = Color(0xFF0A0E17);

  /// Surface color for cards and containers.
  static const Color darkSurface = Color(0xFF151B28);

  /// Elevated surface (modals, dropdowns).
  static const Color darkSurfaceElevated = Color(0xFF1E2636);

  /// Surface variant for subtle differentiation.
  static const Color darkSurfaceVariant = Color(0xFF252D3D);

  // ==========================================================================
  // Light Theme Background Colors
  // ==========================================================================

  /// Light background.
  static const Color lightBackground = Color(0xFFF5F5F5);

  /// Light surface.
  static const Color lightSurface = Color(0xFFFFFFFF);

  /// Light surface variant.
  static const Color lightSurfaceVariant = Color(0xFFE8E8E8);

  // ==========================================================================
  // Faction Colors
  // ==========================================================================

  /// Caldari State - Blue/Grey.
  static const Color caldari = Color(0xFF4A90D9);

  /// Gallente Federation - Green.
  static const Color gallente = Color(0xFF5CB85C);

  /// Amarr Empire - Gold.
  static const Color amarr = Color(0xFFF0AD4E);

  /// Minmatar Republic - Red/Rust.
  static const Color minmatar = Color(0xFFD9534F);

  // ==========================================================================
  // Security Status Colors
  // ==========================================================================

  /// High security (1.0 - 0.5).
  static const Color securityHigh = Color(0xFF00FF00);

  /// Low security (0.4 - 0.1).
  static const Color securityLow = Color(0xFFFFFF00);

  /// Null security (0.0 and below).
  static const Color securityNull = Color(0xFFFF0000);

  /// Wormhole space.
  static const Color securityWormhole = Color(0xFF9966FF);

  // ==========================================================================
  // Status Colors
  // ==========================================================================

  /// Success state.
  static const Color success = Color(0xFF4CAF50);

  /// Warning state.
  static const Color warning = Color(0xFFFFC107);

  /// Error state.
  static const Color error = Color(0xFFF44336);

  /// Info state.
  static const Color info = Color(0xFF2196F3);

  // ==========================================================================
  // ISK Colors
  // ==========================================================================

  /// Positive ISK change (profit).
  static const Color iskPositive = Color(0xFF4CAF50);

  /// Negative ISK change (loss).
  static const Color iskNegative = Color(0xFFF44336);

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  /// Returns the appropriate faction color for a faction ID.
  static Color getFactionColor(int factionId) {
    switch (factionId) {
      case 500001: // Caldari State
        return caldari;
      case 500004: // Gallente Federation
        return gallente;
      case 500003: // Amarr Empire
        return amarr;
      case 500002: // Minmatar Republic
        return minmatar;
      default:
        return evePrimary;
    }
  }

  /// Returns a color for the given security status.
  static Color getSecurityColor(double security) {
    if (security >= 0.5) return securityHigh;
    if (security >= 0.1) return securityLow;
    return securityNull;
  }
}
