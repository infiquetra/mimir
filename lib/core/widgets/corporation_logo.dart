import 'package:flutter/material.dart';
import 'package:mimir/core/config/eve_config.dart';
import 'package:mimir/core/logging/logger.dart';

/// Displays a corporation or alliance logo from the EVE image server.
///
/// Shows a placeholder icon on error or while loading.
class CorporationLogo extends StatelessWidget {
  /// Corporation or alliance ID.
  final int id;

  /// Whether this is an alliance logo (vs corporation).
  final bool isAlliance;

  /// Size of the logo.
  final double size;

  /// Border radius for the logo.
  final double borderRadius;

  /// Background color for the logo container.
  final Color? backgroundColor;

  /// Valid EVE image server sizes (powers of 2)
  static const List<int> _validSizes = [32, 64, 128, 256, 512];

  const CorporationLogo({
    super.key,
    required this.id,
    this.isAlliance = false,
    this.size = 64.0,
    this.borderRadius = 4.0,
    this.backgroundColor,
  });

  /// Creates a corporation logo.
  const CorporationLogo.corporation({
    super.key,
    required int corporationId,
    this.size = 64.0,
    this.borderRadius = 4.0,
    this.backgroundColor,
  })  : id = corporationId,
        isAlliance = false;

  /// Creates an alliance logo.
  const CorporationLogo.alliance({
    super.key,
    required int allianceId,
    this.size = 64.0,
    this.borderRadius = 4.0,
    this.backgroundColor,
  })  : id = allianceId,
        isAlliance = true;

  /// Normalizes size to nearest valid EVE server size (rounds up)
  static int _normalizeSize(double requestedSize) {
    final requested = requestedSize.ceil();
    for (final validSize in _validSizes) {
      if (requested <= validSize) return validSize;
    }
    return _validSizes.last; // Cap at 512
  }

  String get _imageUrl {
    final normalizedSize = _normalizeSize(size);
    final endpoint = isAlliance ? 'alliances' : 'corporations';
    final url = '${EveConfig.imageServerUrl}/$endpoint/$id/logo?size=$normalizedSize';
    Log.d('CORP_LOGO', 'Loading ${isAlliance ? 'alliance' : 'corporation'} logo: $url');
    return url;
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
              isAlliance ? Icons.shield_outlined : Icons.business_outlined,
              size: size * 0.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          );
        },
      ),
    );
  }
}
