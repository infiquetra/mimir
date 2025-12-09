import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../characters/data/character_providers.dart';
import 'character_selector_overlay.dart';

/// A compact button showing the active character with avatar and SP count.
///
/// Displays:
/// - Character avatar (48px with active glow)
/// - Character name
/// - Total SP in compact format (e.g., "190M SP")
/// - Dropdown arrow indicator
///
/// Clicking opens [CharacterSelectorOverlay] to switch characters.
/// If no character selected, shows placeholder state.
class CharacterSelectorButton extends ConsumerWidget {
  const CharacterSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'CharacterSelectorButton - building');
    final theme = Theme.of(context);
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return activeCharacterAsync.when(
      data: (character) {
        if (character == null) {
          // No character selected - show placeholder
          return _buildPlaceholderButton(context);
        }

        // Watch total SP provider for this character
        final totalSpAsync = ref.watch(characterTotalSpProvider(character.characterId));

        return totalSpAsync.when(
          data: (totalSp) => _buildCharacterButton(context, character, totalSp),
          loading: () => _buildPlaceholderButton(context),
          error: (_, __) => _buildCharacterButton(context, character, 0),
        );
      },
      loading: () {
        Log.d('SKILLS.UI', 'CharacterSelectorButton - loading');
        return _buildPlaceholderButton(context);
      },
      error: (_, __) {
        Log.e('SKILLS.UI', 'CharacterSelectorButton - error loading character');
        return _buildPlaceholderButton(context);
      },
    );
  }

  Widget _buildCharacterButton(BuildContext context, dynamic character, int totalSp) {
    final theme = Theme.of(context);
    final spFormatted = _formatSp(totalSp);

    return InkWell(
          onTap: () {
            Log.d('SKILLS.UI', 'CharacterSelectorButton - tapped, opening overlay');
            _showCharacterSelectorOverlay(context);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: EveColors.surfaceDefault,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: EveColors.photonBlue.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Character avatar
                StyledCharacterAvatar(
                  portraitUrl: character.portraitUrl,
                  size: CharacterAvatarSize.large,
                  isActive: true,
                ),
                const SizedBox(width: 12),

                // Character info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Character name
                    Text(
                      character.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Total SP
                    Text(
                      spFormatted,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // Dropdown indicator
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildPlaceholderButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Log.d('SKILLS.UI', 'CharacterSelectorButton (placeholder) - tapped');
        _showCharacterSelectorOverlay(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: EveColors.surfaceDefault,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder avatar
            Container(
              width: CharacterAvatarSize.large.pixels,
              height: CharacterAvatarSize.large.pixels,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Icon(
                Icons.person_outline,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),

            // Placeholder text
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Character',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Select character',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),

            // Dropdown indicator
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showCharacterSelectorOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const CharacterSelectorOverlay(),
    );
  }

  /// Formats SP count in compact form.
  ///
  /// Examples:
  /// - 5,000 → "5K SP"
  /// - 190,000,000 → "190M SP"
  /// - 1,500,000 → "1.5M SP"
  String _formatSp(int sp) {
    if (sp >= 1000000) {
      // Millions
      final millions = sp / 1000000;
      if (millions >= 100) {
        // 100M+ → "190M SP" (no decimal)
        return '${millions.round()}M SP';
      } else {
        // <100M → "1.5M SP" (1 decimal)
        return '${millions.toStringAsFixed(1)}M SP';
      }
    } else if (sp >= 1000) {
      // Thousands
      final thousands = sp / 1000;
      return '${thousands.round()}K SP';
    } else {
      // Less than 1000
      return '$sp SP';
    }
  }
}
