import 'package:flutter/material.dart';
import 'package:mimir/core/config/eve_config.dart';

/// Displays a faction logo from the EVE image server.
///
/// Shows a placeholder icon on error or while loading.
///
/// EVE Online faction IDs:
/// - Caldari State: 500001
/// - Minmatar Republic: 500002
/// - Amarr Empire: 500003
/// - Gallente Federation: 500004
class FactionLogo extends StatelessWidget {
  /// Faction ID.
  final int factionId;

  /// Size of the logo.
  final double size;

  /// Border radius for the logo.
  final double borderRadius;

  /// Background color for the logo container.
  final Color? backgroundColor;

  const FactionLogo({
    super.key,
    required this.factionId,
    this.size = 48.0,
    this.borderRadius = 4.0,
    this.backgroundColor,
  });

  String get _imageUrl {
    // Factions use the corporations endpoint in the image server
    return '${EveConfig.imageServerUrl}/corporations/$factionId/logo?size=${size.toInt()}';
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
          return Center(
            child: Icon(
              Icons.flag_outlined,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
