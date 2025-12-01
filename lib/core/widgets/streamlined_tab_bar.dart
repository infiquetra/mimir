import 'package:flutter/material.dart';

/// A streamlined tab bar with minimal styling, matching EVE Online's UI.
///
/// Features:
/// - Text-only labels (no icons)
/// - Compact padding
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

  /// The height of the tab bar.
  final double height;

  /// Optional text style override.
  final TextStyle? textStyle;

  const StreamlinedTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.height = 40.0,
    this.textStyle,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
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
        // Minimal padding
        padding: const EdgeInsets.symmetric(horizontal: 8),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        // Text styling
        labelStyle: textStyle ??
            theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
        unselectedLabelStyle: textStyle ?? theme.textTheme.bodyMedium,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        // Thin underline indicator
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.0,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 16),
        ),
        // Remove default divider (we have our own border)
        dividerColor: Colors.transparent,
        // Smooth animation
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}
