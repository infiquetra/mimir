import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../database/app_database.dart' show isSubWindow;

/// Size presets for character avatars.
enum CharacterAvatarSize {
  /// Small avatar (32px) - used for secondary/non-active characters.
  small(32),

  /// Medium avatar (40px) - used for compact displays.
  medium(40),

  /// Large avatar (48px) - used for active character display.
  large(48);

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

  /// Optional tooltip to show on hover.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(102),
                  blurRadius: 8,
                  spreadRadius: 1,
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

    if (onTap != null) {
      avatar = GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    if (tooltip != null) {
      avatar = Tooltip(
        message: tooltip!,
        child: avatar,
      );
    }

    return avatar;
  }
}
