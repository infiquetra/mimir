import 'package:flutter/material.dart';
import 'package:mimir/core/config/eve_config.dart';
import 'package:mimir/core/logging/logger.dart';

/// Displays an EVE Online type icon (ship, implant, module, etc.).
///
/// Uses the EVE image server to fetch type icons.
/// Shows a placeholder icon on error or while loading.
///
/// The EVE Image Server only accepts specific size values (powers of 2).
/// This widget automatically normalizes requested sizes to the nearest valid size.
class EveTypeIcon extends StatelessWidget {
  /// Type ID from EVE SDE.
  final int typeId;

  /// Size of the icon.
  final double size;

  /// Border radius for the icon.
  final double borderRadius;

  /// Background color for the icon container.
  final Color? backgroundColor;

  /// Valid EVE image server sizes (powers of 2)
  static const List<int> _validSizes = [32, 64, 128, 256, 512, 1024];

  const EveTypeIcon({
    super.key,
    required this.typeId,
    this.size = 64.0,
    this.borderRadius = 4.0,
    this.backgroundColor,
  });

  /// Normalizes size to nearest valid EVE server size (rounds up)
  static int _normalizeSize(double requestedSize) {
    final requested = requestedSize.ceil();
    for (final validSize in _validSizes) {
      if (requested <= validSize) return validSize;
    }
    return _validSizes.last; // Cap at 1024
  }

  String get _imageUrl {
    final normalizedSize = _normalizeSize(size);
    return '${EveConfig.imageServerUrl}/types/$typeId/icon?size=$normalizedSize';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        _imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: size * 0.5,
              height: size * 0.5,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          Log.e('EveTypeIcon', 'Failed to load icon for type $typeId from $_imageUrl', error, stackTrace);
          return Center(
            child: Icon(
              Icons.help_outline,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
