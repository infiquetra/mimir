import 'package:flutter/material.dart';

/// Displays security status with color-coded indicator.
///
/// Security status ranges from -10.0 (criminal) to +10.0 (exemplary).
/// Colors follow EVE Online conventions:
/// - Red: -10.0 to -5.0 (outlaw)
/// - Orange: -5.0 to 0.0 (suspect)
/// - Yellow: 0.0 to 2.0 (neutral)
/// - Green: 2.0 to 5.0 (good standing)
/// - Blue: 5.0 to 10.0 (excellent standing)
class SecurityStatusBadge extends StatelessWidget {
  /// Security status value (-10.0 to +10.0).
  final double securityStatus;

  /// Whether to show the numeric value.
  final bool showValue;

  /// Size of the badge.
  final double size;

  const SecurityStatusBadge({
    super.key,
    required this.securityStatus,
    this.showValue = true,
    this.size = 32.0,
  });

  Color get _statusColor {
    if (securityStatus < -5.0) {
      return Colors.red.shade700;
    } else if (securityStatus < 0.0) {
      return Colors.orange.shade700;
    } else if (securityStatus < 2.0) {
      return Colors.yellow.shade700;
    } else if (securityStatus < 5.0) {
      return Colors.green.shade700;
    } else {
      return Colors.blue.shade700;
    }
  }

  String get _statusText {
    return securityStatus.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (!showValue) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _statusColor,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.2),
        border: Border.all(color: _statusColor, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _statusText,
        style: TextStyle(
          color: _statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
