import 'package:flutter/material.dart';

/// EVE Online Photon UI color palette.
///
/// These colors are based on EVE Online's modern Photon UI design system,
/// with darker backgrounds, refined blues, and proper text hierarchy.
abstract class EveColors {
  // ==========================================================================
  // Primary Colors (Photon Dark)
  // ==========================================================================

  /// Photon Blue - Primary brand color (electric blue, less saturated).
  static const Color photonBlue = Color(0xFF1E90FF);

  /// Photon Cyan - Secondary accent.
  static const Color photonCyan = Color(0xFF00CED1);

  /// Photon Highlight - Royal blue for selection/hover.
  static const Color photonHighlight = Color(0xFF4169E1);

  // Legacy aliases for backwards compatibility
  static const Color evePrimary = photonBlue;
  static const Color eveSecondary = photonCyan;
  static const Color eveTertiary = photonHighlight;

  // ==========================================================================
  // Dark Theme Backgrounds (Darker, more muted)
  // ==========================================================================

  /// Nearly black - Deepest background.
  static const Color backgroundDeep = Color(0xFF050810);

  /// Primary background.
  static const Color backgroundBase = Color(0xFF0C1018);

  /// Card surface.
  static const Color surfaceDefault = Color(0xFF121820);

  /// Elevated surfaces (modals, dropdowns).
  static const Color surfaceElevated = Color(0xFF181F28);

  /// Hover states.
  static const Color surfaceBright = Color(0xFF1E2530);

  // Legacy aliases
  static const Color darkBackground = backgroundBase;
  static const Color darkSurface = surfaceDefault;
  static const Color darkSurfaceElevated = surfaceElevated;
  static const Color darkSurfaceVariant = surfaceBright;

  // ==========================================================================
  // Borders & Dividers
  // ==========================================================================

  /// Subtle border (10% white equivalent).
  static const Color borderSubtle = Color(0xFF2A3240);

  /// Active/highlighted borders.
  static const Color borderActive = Color(0xFF3A4250);

  /// Section dividers.
  static const Color divider = Color(0xFF1A2030);

  // ==========================================================================
  // Text Hierarchy (Photon Dark)
  // ==========================================================================

  /// Primary text (91% white) - Main content.
  static const Color textPrimary = Color(0xFFE8ECF0);

  /// Secondary text (63% white) - Supporting content.
  static const Color textSecondary = Color(0xFFA0A8B0);

  /// Tertiary text (38% white) - Metadata, timestamps.
  static const Color textTertiary = Color(0xFF606870);

  /// Disabled text (25% white) - Inactive elements.
  static const Color textDisabled = Color(0xFF404850);

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
  // Faction Colors (Slightly muted for Photon Dark)
  // ==========================================================================

  /// Caldari State - Steel blue.
  static const Color caldari = Color(0xFF3D7AB8);

  /// Gallente Federation - Forest green.
  static const Color gallente = Color(0xFF4CA84C);

  /// Amarr Empire - Antique gold.
  static const Color amarr = Color(0xFFC99A40);

  /// Minmatar Republic - Rust red.
  static const Color minmatar = Color(0xFFB84D4D);

  // ==========================================================================
  // Security Status Colors (EVE-accurate, high contrast)
  // ==========================================================================

  /// High security (1.0 - 0.5) - High-sec green.
  static const Color securityHigh = Color(0xFF00CC00);

  /// Low security (0.4 - 0.1) - Low-sec yellow.
  static const Color securityLow = Color(0xFFCCCC00);

  /// Null security (0.0 and below) - Null-sec red.
  static const Color securityNull = Color(0xFFCC0000);

  /// Wormhole space - Purple.
  static const Color securityWormhole = Color(0xFF7F00FF);

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
  // ISK Colors (Profit/Loss)
  // ==========================================================================

  /// Positive ISK change (profit) - Profit green.
  static const Color iskPositive = Color(0xFF00CC66);

  /// Negative ISK change (loss) - Loss red.
  static const Color iskNegative = Color(0xFFCC3333);

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
