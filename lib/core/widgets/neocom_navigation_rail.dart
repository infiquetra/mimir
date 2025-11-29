import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';
import '../window/window_types.dart';

/// EVE Online Neocom-styled navigation rail.
///
/// Features:
/// - EVE SVG icons for authentic game feel
/// - Glow effect on selected icons
/// - Hover glow on desktop
/// - Subtle border/divider styling
/// - Dark surface background matching EVE aesthetics
///
/// ```dart
/// NeocomNavigationRail(
///   selectedIndex: 0,
///   onDestinationSelected: (index) => navigate(index),
///   leading: CharacterSelector(),
///   destinations: [...],
/// )
/// ```
class NeocomNavigationRail extends StatelessWidget {
  const NeocomNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.leading,
    this.trailing,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NeocomDestination> destinations;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: EveColors.darkSurface,
        border: Border(
          right: BorderSide(
            color: EveColors.evePrimary.withAlpha(51), // 20% opacity
            width: 1,
          ),
        ),
        // Subtle glow on the right edge
        boxShadow: [
          BoxShadow(
            color: EveColors.evePrimary.withAlpha(13), // 5% opacity
            blurRadius: 8,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (leading != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 64,
                  child: Center(child: leading!),
                ),
              ),
              _buildDivider(),
            ],
            const SizedBox(height: 8),
            ...destinations.asMap().entries.map((entry) {
              final index = entry.key;
              final destination = entry.value;
              return _NeocomNavItem(
                destination: destination,
                isSelected: index == selectedIndex,
                onTap: () => onDestinationSelected(index),
              );
            }),
            const Spacer(),
            if (trailing != null) ...[
              _buildDivider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            EveColors.evePrimary.withAlpha(77), // 30% in center
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// A destination for the Neocom navigation rail.
///
/// Supports both EVE PNG icons (via [windowType]) and Material icons
/// (via [icon] and [selectedIcon]).
class NeocomDestination {
  const NeocomDestination({
    required this.label,
    this.windowType,
    this.icon,
    this.selectedIcon,
  }) : assert(
          windowType != null || (icon != null && selectedIcon != null),
          'Either windowType or icon/selectedIcon must be provided',
        );

  /// The window type for EVE PNG icons. If provided, uses the icon
  /// asset from [WindowType.iconAsset].
  final WindowType? windowType;

  /// Fallback Material icon when not using PNG.
  final IconData? icon;

  /// Fallback Material icon when selected and not using PNG.
  final IconData? selectedIcon;

  /// Label displayed below the icon.
  final String label;

  /// Returns true if this destination uses an EVE PNG icon.
  bool get usesPngIcon => windowType != null;

  /// Gets the PNG asset path for this destination.
  String? get pngAsset => windowType?.iconAsset;
}

/// Individual navigation item with glow effects.
class _NeocomNavItem extends StatefulWidget {
  const _NeocomNavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final NeocomDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NeocomNavItem> createState() => _NeocomNavItemState();
}

class _NeocomNavItemState extends State<_NeocomNavItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeOut),
    );

    if (widget.isSelected) {
      _glowController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_NeocomNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _glowController.forward();
      } else {
        _glowController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final glowIntensity = _glowAnimation.value;
            final hoverIntensity = _isHovered && !widget.isSelected ? 0.3 : 0.0;
            final totalIntensity =
                (glowIntensity + hoverIntensity).clamp(0.0, 1.0);

            // Determine icon color based on state
            final iconColor = widget.isSelected
                ? EveColors.evePrimary
                : _isHovered
                    ? EveColors.evePrimary.withAlpha(204)
                    : Colors.white.withAlpha(179); // 70%

            return Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.isSelected
                    ? EveColors.evePrimary.withAlpha(26) // 10% fill
                    : _isHovered
                        ? EveColors.darkSurfaceVariant.withAlpha(128)
                        : Colors.transparent,
                border: Border.all(
                  color: EveColors.evePrimary.withAlpha(
                    (totalIntensity * 128).round(),
                  ),
                  width: widget.isSelected ? 1.5 : 1,
                ),
                boxShadow: totalIntensity > 0
                    ? [
                        BoxShadow(
                          color: EveColors.evePrimary.withAlpha(
                            (totalIntensity * 77).round(), // Up to 30%
                          ),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: EveColors.evePrimary.withAlpha(
                            (totalIntensity * 38).round(), // Up to 15%
                          ),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Render SVG or Material icon
                  _buildIcon(iconColor),
                  const SizedBox(height: 4),
                  Text(
                    widget.destination.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: widget.isSelected
                          ? EveColors.evePrimary
                          : _isHovered
                              ? EveColors.evePrimary.withAlpha(204)
                              : Colors.white.withAlpha(153), // 60%
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Builds either a PNG icon or Material icon based on the destination.
  Widget _buildIcon(Color color) {
    if (widget.destination.usesPngIcon) {
      return Image.asset(
        widget.destination.pngAsset!,
        width: 24,
        height: 24,
        // PNG icons from EVE Wiki are already styled, just apply opacity
        color: color,
        colorBlendMode: BlendMode.srcIn,
      );
    }

    // Fallback to Material icons
    return Icon(
      widget.isSelected
          ? widget.destination.selectedIcon
          : widget.destination.icon,
      size: 24,
      color: color,
    );
  }
}
