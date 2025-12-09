import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/character_avatar.dart';
import '../../../characters/data/character_providers.dart';

/// Discord-style vertical character navigation rail.
///
/// Displays:
/// - Stacked character avatars (40px each)
/// - Active character with blue glow
/// - Add character button at bottom (+)
/// - Fixed 60px width
///
/// Click avatar to switch character instantly.
class CharacterNavRail extends ConsumerWidget {
  const CharacterNavRail({super.key});

  static const double width = 60.0;
  static const double avatarSize = 40.0;
  static const double spacing = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'CharacterNavRail - building');
    final theme = Theme.of(context);
    final charactersAsync = ref.watch(allCharactersProvider);
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: charactersAsync.when(
        data: (characters) {
          if (characters.isEmpty) {
            return _buildEmptyState(context);
          }

          return Column(
            children: [
              // Character avatars
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: characters.length,
                  itemBuilder: (context, index) {
                    final character = characters[index];
                    final isActive =
                        character.characterId == activeCharacter?.characterId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: spacing),
                      child: _buildCharacterAvatar(
                        context,
                        ref,
                        character,
                        isActive: isActive,
                      ),
                    );
                  },
                ),
              ),

              // Add character button
              _buildAddCharacterButton(context),
              const SizedBox(height: 8),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: EveColors.photonBlue,
            strokeWidth: 2,
          ),
        ),
        error: (error, _) {
          Log.e('SKILLS.UI', 'CharacterNavRail - error loading characters', error);
          return _buildErrorState(context);
        },
      ),
    );
  }

  Widget _buildCharacterAvatar(
    BuildContext context,
    WidgetRef ref,
    dynamic character, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: GestureDetector(
        onTap: () async {
          if (isActive) {
            Log.d('SKILLS.UI', 'CharacterNavRail - already active character');
            return;
          }

          Log.i('SKILLS.UI', 'CharacterNavRail - switching to character ${character.characterId}');
          try {
            await ref.read(databaseProvider).setActiveCharacter(character.characterId);
          } catch (e, stack) {
            Log.e('SKILLS.UI', 'CharacterNavRail - failed to switch character', e, stack);
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
        child: Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? EveColors.photonBlue
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: EveColors.photonBlue.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: ClipOval(
            child: StyledCharacterAvatar(
              portraitUrl: character.portraitUrl,
              size: CharacterAvatarSize.medium,
              isActive: isActive,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddCharacterButton(BuildContext context) {
    return Center(
      child: Tooltip(
        message: 'Add Character',
        child: InkWell(
          onTap: () {
            Log.i('SKILLS.UI', 'CharacterNavRail - add character tapped');
            context.push('/add-character');
          },
          borderRadius: BorderRadius.circular(avatarSize / 2),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EveColors.surfaceElevated,
              border: Border.all(
                color: EveColors.photonBlue.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 24,
              color: EveColors.photonBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            _buildAddCharacterButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Icon(
        Icons.error_outline,
        size: 32,
        color: theme.colorScheme.error,
      ),
    );
  }
}
