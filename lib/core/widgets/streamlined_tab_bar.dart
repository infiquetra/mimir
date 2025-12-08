import 'package:flutter/material.dart';

import '../theme/eve_colors.dart';
import '../theme/eve_spacing.dart';
import '../theme/eve_typography.dart';

/// A streamlined tab bar with minimal styling, matching EVE Online Photon UI.
///
/// Features:
/// - Text-only labels (no icons)
/// - Compact 32px height (was 40px)
/// - Thin underline indicator
/// - Clean, professional appearance
///
/// Usage:
/// ```dart
/// TabController _controller = TabController(length: 3, vsync: this);
///
/// StreamlinedTabBar(
///   controller: _controller,
///   tabs: ['Character', 'Interactions', 'History'],
/// )
/// ```
class StreamlinedTabBar extends StatelessWidget implements PreferredSizeWidget {
  /// The tab controller.
  final TabController controller;

  /// The tab labels.
  final List<String> tabs;

  /// The height of the tab bar. Defaults to 32px (EveSpacing.tabBarHeight).
  final double height;

  /// Optional text style override.
  final TextStyle? textStyle;

  const StreamlinedTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.height = EveSpacing.tabBarHeight,
    this.textStyle,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: EveColors.borderSubtle.withAlpha(77), // 30% opacity
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs
            .map((label) => Tab(
                  height: height,
                  child: Text(label),
                ))
            .toList(),
        // Compact padding (8px screen edge, 12px between tabs)
        padding: EdgeInsets.symmetric(horizontal: EveSpacing.md),
        labelPadding: EdgeInsets.symmetric(horizontal: EveSpacing.lg),
        // Text styling with EVE typography
        labelStyle: textStyle ??
            EveTypography.labelLarge(color: EveColors.photonBlue),
        unselectedLabelStyle:
            textStyle ?? EveTypography.labelLarge(color: EveColors.textSecondary),
        labelColor: EveColors.photonBlue,
        unselectedLabelColor: EveColors.textSecondary,
        // Thin 2px underline indicator
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            color: EveColors.photonBlue,
            width: 2.0,
          ),
          insets: EdgeInsets.symmetric(horizontal: EveSpacing.lg),
        ),
        // Remove default divider (we have our own border)
        dividerColor: Colors.transparent,
        // Smooth animation
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
