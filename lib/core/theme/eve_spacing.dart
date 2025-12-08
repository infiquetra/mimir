/// EVE Online Photon UI spacing system.
///
/// Based on an 8pt grid system for consistent, compact layouts.
/// All values follow the Photon Dark specification for balanced information density.
abstract class EveSpacing {
  // ==========================================================================
  // Base Spacing (8pt grid)
  // ==========================================================================

  /// Micro gaps (2px) - Between tightly related elements.
  static const double xs = 2.0;

  /// Tight spacing (4px) - Icons to text, chip padding.
  static const double sm = 4.0;

  /// Standard gap (8px) - Default spacing between elements.
  static const double md = 8.0;

  /// Section spacing (12px) - Between related groups.
  static const double lg = 12.0;

  /// Screen margins (16px) - Page edge padding.
  static const double xl = 16.0;

  /// Major sections (24px) - Between distinct content areas.
  static const double xxl = 24.0;

  // ==========================================================================
  // Component Padding
  // ==========================================================================

  /// Standard card padding (12px) - Balanced, not too spacious.
  static const double cardPadding = 12.0;

  /// Tight card padding (8px) - For dense information display.
  static const double cardPaddingTight = 8.0;

  /// Large card padding (16px) - For important/featured content.
  static const double cardPaddingLarge = 16.0;

  /// Button padding horizontal (16px).
  static const double buttonPaddingH = 16.0;

  /// Button padding vertical (8px).
  static const double buttonPaddingV = 8.0;

  /// Chip padding horizontal (12px).
  static const double chipPaddingH = 12.0;

  /// Chip padding vertical (6px).
  static const double chipPaddingV = 6.0;

  // ==========================================================================
  // Border Radius (Sharper, more technical)
  // ==========================================================================

  /// Card border radius (6px) - Sharper than before (was 12px).
  static const double cardRadius = 6.0;

  /// Button border radius (4px) - Tight, technical.
  static const double buttonRadius = 4.0;

  /// Input field border radius (4px).
  static const double inputRadius = 4.0;

  /// Dialog border radius (8px).
  static const double dialogRadius = 8.0;

  /// Chip border radius (4px).
  static const double chipRadius = 4.0;

  // ==========================================================================
  // Icon Sizes
  // ==========================================================================

  /// Extra small icon (16px) - Inline with text.
  static const double iconXs = 16.0;

  /// Small icon (20px) - List items, compact displays.
  static const double iconSm = 20.0;

  /// Medium icon (24px) - Standard icon size.
  static const double iconMd = 24.0;

  /// Large icon (32px) - Featured icons, buttons.
  static const double iconLg = 32.0;

  /// Extra large icon (48px) - Hero elements.
  static const double iconXl = 48.0;

  // ==========================================================================
  // Avatar Sizes
  // ==========================================================================

  /// Small avatar (24px) - Compact lists, inline mentions.
  static const double avatarSm = 24.0;

  /// Medium avatar (32px) - Standard display.
  static const double avatarMd = 32.0;

  /// Large avatar (48px) - Featured display.
  static const double avatarLg = 48.0;

  /// Hero avatar (80px) - Character sheet (was 120px).
  static const double avatarHero = 80.0;

  // ==========================================================================
  // Component Heights
  // ==========================================================================

  /// Compact row height (28px) - Data tables, skill queue items.
  static const double rowHeight = 28.0;

  /// Tab bar height (32px) - Compact tab navigation (was 40px).
  static const double tabBarHeight = 32.0;

  /// Balance chip height (36px) - Wallet balance display.
  static const double balanceChipHeight = 36.0;

  /// AppBar action button size (40px).
  static const double appBarActionSize = 40.0;

  // ==========================================================================
  // Touch Targets (macOS optimized)
  // ==========================================================================

  /// Minimum clickable area (32px).
  static const double minTouch = 32.0;

  /// Preferred clickable area (36px) - Comfortable for most interactions.
  static const double preferredTouch = 36.0;

  // ==========================================================================
  // Glow Effects (Pronounced style)
  // ==========================================================================

  /// Primary glow blur radius (16px).
  static const double glowBlurPrimary = 16.0;

  /// Outer glow blur radius (32px) - Secondary dramatic effect.
  static const double glowBlurOuter = 32.0;

  /// Glow spread radius (2px).
  static const double glowSpread = 2.0;

  /// Base glow intensity (0.4 = 40% opacity).
  static const double glowIntensity = 0.4;

  /// Hover glow multiplier (1.5x = 60% on hover).
  static const double glowHoverMultiplier = 1.5;
}
