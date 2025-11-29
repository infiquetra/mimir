import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';
import '../window/window_types.dart';

/// EVE Online-styled navigation icon using PNG assets.
///
/// Displays an icon from the bundled EVE PNG assets with support for:
/// - Selected/unselected states with color changes
/// - Glow effects when selected
/// - Consistent sizing across navigation items
///
/// Icons sourced from EVE University Wiki:
/// https://wiki.eveuniversity.org/UniWiki:Icons
///
/// ```dart
/// EveNavIcon(
///   windowType: WindowType.dashboard,
///   isSelected: true,
///   size: 24,
/// )
/// ```
class EveNavIcon extends StatelessWidget {
  const EveNavIcon({
    required this.windowType,
    this.isSelected = false,
    this.size = 24,
    this.color,
    super.key,
  });

  /// The window type determines which PNG asset to display.
  final WindowType windowType;

  /// Whether this icon is currently selected in the navigation.
  final bool isSelected;

  /// The size of the icon in logical pixels.
  final double size;

  /// Optional override color. If null, uses default EVE colors
  /// based on [isSelected] state.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Determine icon color based on selection state
    final iconColor = color ??
        (isSelected
            ? EveColors.evePrimary
            : Colors.white.withAlpha(179)); // 70% white when unselected

    return Image.asset(
      windowType.iconAsset,
      width: size,
      height: size,
      color: iconColor,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

/// A navigation destination that can display either an EVE PNG icon
/// or a fallback Material icon.
///
/// Used by the NeocomNavigationRail to show EVE-styled icons.
class EveNavDestination {
  const EveNavDestination({
    required this.windowType,
    required this.label,
    this.fallbackIcon,
    this.fallbackSelectedIcon,
  });

  /// The window type for this destination.
  final WindowType windowType;

  /// Label displayed below the icon.
  final String label;

  /// Fallback Material icon when PNG fails to load.
  final IconData? fallbackIcon;

  /// Fallback Material icon when selected.
  final IconData? fallbackSelectedIcon;

  /// Returns the appropriate icon widget based on selection state.
  Widget buildIcon({
    required bool isSelected,
    required double size,
    Color? color,
  }) {
    return EveNavIcon(
      windowType: windowType,
      isSelected: isSelected,
      size: size,
      color: color,
    );
  }
}
