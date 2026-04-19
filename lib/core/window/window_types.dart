// lib/core/window/window_types.dart
import 'package:flutter/material.dart';
import 'package:mimir/features/industry/presentation/industry_screen.dart';

/// Abstract base class for all window types in the application
abstract class WindowType {
  final String id;
  final String title;
  final IconData icon;

  WindowType({
    required this.id,
    required this.title,
    required this.icon,
  });

  /// Build the content widget for this window
  Widget buildContent(BuildContext context);

  /// Called when the window is opened
  void onOpen() {}

  /// Called when the window is closed
  void onClose() {}

  /// Whether this window supports tabs
  bool get supportsTabs => false;

  /// Whether this window supports pop-out functionality
  bool get supportsPopOut => false;
}

/// Industry window type implementation
class IndustryWindow extends WindowType {
  IndustryWindow()
      : super(
          id: 'industry',
          title: 'Industry',
          icon: Icons.factory_outlined,
        );

  @override
  bool get supportsTabs => true;

  @override
  bool get supportsPopOut => true;

  @override
  Widget buildContent(BuildContext context) {
    return const IndustryScreen();
  }
}
