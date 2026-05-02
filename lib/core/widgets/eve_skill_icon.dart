import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../database/app_database.dart' show isSubWindow;
import '../theme/eve_colors.dart';

/// Displays an EVE Online skill (or type) icon from the EVE Image API.
///
/// Uses [CachedNetworkImage] for efficient caching and offline support.
/// Shows a shimmer placeholder during loading and a fallback icon on error.
///
/// For sub-windows that don't have access to native plugins, set [useCache]
/// to `false` to use simple `Image.network` instead.
///
/// ```dart
/// EveSkillIcon(
///   typeId: 3413,  // Spaceship Command
///   size: 32,
/// )
/// ```
class EveSkillIcon extends StatelessWidget {
  const EveSkillIcon({
    super.key,
    required this.typeId,
    this.size = 32,
    this.showBorder = false,
    this.borderColor,
    this.useCache = true,
  });

  /// The EVE type ID of the skill/item.
  final int typeId;

  /// Size of the icon (width and height). Defaults to 32.
  /// EVE API supports: 32, 64, 128, 256, 512.
  final double size;

  /// Whether to show a glowing border around the icon.
  final bool showBorder;

  /// Custom border color. Defaults to [EveColors.evePrimary].
  final Color? borderColor;

  /// Whether to use disk caching via CachedNetworkImage.
  /// Set to `false` for sub-windows that can't access native plugins.
  final bool useCache;

  /// Base URL for EVE Online type icons.
  static const String _baseUrl = 'https://images.evetech.net/types';

  /// Generates the icon URL for a given type ID and size.
  static String getIconUrl(int typeId, {int size = 64}) {
    // EVE API supports specific sizes: 32, 64, 128, 256, 512
    final apiSize = _normalizeSize(size);
    return '$_baseUrl/$typeId/icon?size=$apiSize';
  }

  /// Normalizes size to nearest supported API size.
  static int _normalizeSize(int requestedSize) {
    if (requestedSize <= 32) return 32;
    if (requestedSize <= 64) return 64;
    if (requestedSize <= 128) return 128;
    if (requestedSize <= 256) return 256;
    return 512;
  }

  @override
  Widget build(BuildContext context) {
    final iconUrl = getIconUrl(typeId, size: size.toInt());
    final effectiveBorderColor = borderColor ?? EveColors.evePrimary;

    // Determine if caching is available. Sub-windows can't use disk caching
    // because CachedNetworkImage uses path_provider which isn't available.
    final canUseCache = useCache && !isSubWindow;

    // Use CachedNetworkImage for disk caching in main window,
    // or Image.network for sub-windows without native plugin access.
    Widget icon = canUseCache
        ? CachedNetworkImage(
            imageUrl: iconUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholder(),
            errorWidget: (context, url, error) => _buildErrorIcon(),
          )
        : Image.network(
            iconUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildPlaceholder();
            },
            errorBuilder: (context, error, stackTrace) => _buildErrorIcon(),
          );

    // Apply rounded corners
    icon = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: icon,
    );

    // Apply glow border if requested
    if (showBorder) {
      icon = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: effectiveBorderColor.withAlpha(102), // 40% opacity
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: effectiveBorderColor.withAlpha(179), // 70% opacity
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: icon,
      );
    }

    return icon;
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: EveColors.darkSurfaceVariant,
      highlightColor: EveColors.darkSurface,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: EveColors.darkSurfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildErrorIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.help_outline_rounded,
            size: size * 0.5,
            color: EveColors.evePrimary.withAlpha(76),
          ),
          // Subtly branded corner
          Positioned(
            bottom: 2,
            right: 2,
            child: Icon(
              Icons.square_rounded,
              size: size * 0.15,
              color: EveColors.evePrimary.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }
}
