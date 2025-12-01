import 'package:flutter/material.dart';

/// Displays a colored dot indicating online/offline status.
///
/// Shows a green dot when online, gray when offline.
/// Used in character lists and status displays.
class OnlineIndicator extends StatelessWidget {
  /// Whether the character is online.
  final bool isOnline;

  /// Size of the indicator dot.
  final double size;

  const OnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.green : Colors.grey.shade600,
        boxShadow: isOnline
            ? [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}
