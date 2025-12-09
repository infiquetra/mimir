import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../characters/data/character_providers.dart';

/// Overlay dialog for selecting/switching between characters.
///
/// Displays:
/// - List of all configured characters
/// - Highlight active character
/// - Character portrait, name, corporation, SP
/// - Click to switch character
/// - "Add Character" button at bottom
///
/// Automatically closes after character selection.
class CharacterSelectorOverlay extends ConsumerWidget {
  const CharacterSelectorOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'CharacterSelectorOverlay - building');
    final theme = Theme.of(context);
    final charactersAsync = ref.watch(allCharactersProvider);
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: EveColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: EveColors.surfaceDefault,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 20,
                    color: EveColors.photonBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Select Character',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      Log.d('SKILLS.UI', 'CharacterSelectorOverlay - closed');
                      Navigator.of(context).pop();
                    },
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Character list
            charactersAsync.when(
              data: (characters) {
                if (characters.isEmpty) {
                  return _buildEmptyState(context);
                }

                return Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: characters.length,
                    itemBuilder: (context, index) {
                      final character = characters[index];
                      final isActive = activeCharacter?.characterId == character.characterId;

                      return _buildCharacterTile(
                        context,
                        ref,
                        character,
                        isActive: isActive,
                      );
                    },
                  ),
                );
              },
              loading: () => Padding(
                padding: const EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(
                    color: EveColors.photonBlue,
                  ),
                ),
              ),
              error: (error, _) => _buildErrorState(context, error),
            ),

            // Footer with Add Character button
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EveColors.surfaceDefault,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
              ),
              child: OutlinedButton.icon(
                onPressed: () {
                  Log.d('SKILLS.UI', 'CharacterSelectorOverlay - add character tapped');
                  Navigator.of(context).pop();
                  // Navigate to add character screen
                  context.push('/add-character');
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Character'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EveColors.photonBlue,
                  side: BorderSide(color: EveColors.photonBlue.withOpacity(0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterTile(
    BuildContext context,
    WidgetRef ref,
    dynamic character, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);

    // Watch total SP provider for this character
    final totalSpAsync = ref.watch(characterTotalSpProvider(character.characterId));
    final totalSp = totalSpAsync.when(
      data: (sp) => sp,
      loading: () => 0,
      error: (_, __) => 0,
    );
    final spFormatted = NumberFormat('#,###').format(totalSp);

    return InkWell(
      onTap: () async {
        if (isActive) {
          Log.d('SKILLS.UI', 'CharacterSelectorOverlay - already active character');
          Navigator.of(context).pop();
          return;
        }

        Log.d('SKILLS.UI', 'CharacterSelectorOverlay - switching to character ${character.characterId}');
        try {
          await ref.read(databaseProvider).setActiveCharacter(character.characterId);
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        } catch (e, stack) {
          Log.e('SKILLS.UI', 'CharacterSelectorOverlay - failed to switch character', e, stack);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to switch character: $e'),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive
              ? EveColors.photonBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? EveColors.photonBlue
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Character avatar
            StyledCharacterAvatar(
              portraitUrl: character.portraitUrl,
              size: CharacterAvatarSize.large,
              isActive: isActive,
            ),
            const SizedBox(width: 12),

            // Character info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          character.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? EveColors.photonBlue
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EveColors.photonBlue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: EveColors.photonBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Corporation
                  Text(
                    character.corporationName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Total SP
                  Row(
                    children: [
                      Icon(
                        Icons.stars_outlined,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$spFormatted SP',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            if (!isActive)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Characters',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a character to get started',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Characters',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
