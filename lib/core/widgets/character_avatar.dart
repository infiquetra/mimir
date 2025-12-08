import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../database/app_database.dart' show isSubWindow;
import '../theme/eve_colors.dart';
import '../theme/eve_spacing.dart';

/// Size presets for character avatars (Photon Dark sizing).
enum CharacterAvatarSize {
  /// Small avatar (24px) - compact lists, inline mentions.
  small(EveSpacing.avatarSm),

  /// Medium avatar (32px) - standard display.
  medium(EveSpacing.avatarMd),

  /// Large avatar (48px) - featured display.
  large(EveSpacing.avatarLg),

  /// Hero avatar (80px) - character sheet, major display (was 120px).
  hero(EveSpacing.avatarHero);

  const CharacterAvatarSize(this.pixels);

  /// The size in logical pixels.
  final double pixels;
}

/// Circular avatar showing a character's portrait.
///
/// Uses [CachedNetworkImage] for disk caching in the main window,
/// or [Image.network] for sub-windows that can't access native plugins.
///
/// Example usage:
/// ```dart
/// CharacterAvatar(
///   portraitUrl: character.portraitUrl,
///   size: CharacterAvatarSize.large,
/// )
/// ```
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    required this.portraitUrl,
    this.size = CharacterAvatarSize.medium,
    this.customSize,
    super.key,
  });

  /// URL of the character portrait image.
  final String portraitUrl;

  /// Size preset for the avatar.
  final CharacterAvatarSize size;

  /// Custom size in pixels. If provided, overrides [size].
  final double? customSize;

  @override
  Widget build(BuildContext context) {
    final pixels = customSize ?? size.pixels;

    final placeholder = Container(
      width: pixels,
      height: pixels,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: pixels * 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    // Use Image.network for sub-windows (CachedNetworkImage uses path_provider
    // which isn't available in sub-window isolates).
    final imageWidget = isSubWindow
        ? Image.network(
            portraitUrl,
            width: pixels,
            height: pixels,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
            errorBuilder: (context, error, stackTrace) => placeholder,
          )
        : CachedNetworkImage(
            imageUrl: portraitUrl,
            width: pixels,
            height: pixels,
            fit: BoxFit.cover,
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => placeholder,
          );

    return ClipOval(child: imageWidget);
  }
}

/// A character avatar with active state styling (border and glow).
///
/// Use this for displaying character avatars that need to indicate
/// whether they are currently active/selected.
class StyledCharacterAvatar extends StatelessWidget {
  const StyledCharacterAvatar({
    required this.portraitUrl,
    this.size = CharacterAvatarSize.medium,
    this.isActive = false,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.tooltip,
    super.key,
  });

  /// URL of the character portrait image.
  final String portraitUrl;

  /// Size preset for the avatar.
  final CharacterAvatarSize size;

  /// Whether this avatar represents the active character.
  final bool isActive;

  /// Callback when tapped. If null, the avatar is not tappable.
  final VoidCallback? onTap;

  /// Callback when long-pressed (mobile) or right-clicked (desktop).
  /// Used for showing context menus (e.g., remove character).
  final VoidCallback? onLongPress;

  /// Callback when right-clicked/secondary-tapped (desktop).
  /// Used for showing context menus (e.g., remove character).
  final VoidCallback? onSecondaryTap;

  /// Optional tooltip to show on hover.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Use pronounced glow effect for active avatars
    Widget avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color:
              isActive ? EveColors.photonBlue : EveColors.borderSubtle,
          width: 2,
        ),
        boxShadow: isActive
            ? [
                // Primary glow (16px blur)
                BoxShadow(
                  color: EveColors.photonBlue
                      .withAlpha((EveSpacing.glowIntensity * 255).round()),
                  blurRadius: EveSpacing.glowBlurPrimary,
                  spreadRadius: EveSpacing.glowSpread,
                ),
                // Outer glow (32px blur, half intensity)
                BoxShadow(
                  color: EveColors.photonBlue
                      .withAlpha((EveSpacing.glowIntensity * 128).round()),
                  blurRadius: EveSpacing.glowBlurOuter,
                  spreadRadius: EveSpacing.glowSpread,
                ),
              ]
            : null,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.6,
        child: CharacterAvatar(
          portraitUrl: portraitUrl,
          size: size,
        ),
      ),
    );

    // Apply tooltip FIRST (innermost) so it doesn't interfere with gestures
    if (tooltip != null) {
      avatar = Tooltip(
        message: tooltip!,
        child: avatar,
      );
    }

    // Apply gesture detector LAST (outermost) for proper event handling
    if (onTap != null || onLongPress != null || onSecondaryTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        child: avatar,
      );
    }

    return avatar;
  }
}
