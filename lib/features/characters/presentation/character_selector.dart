import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../data/character_providers.dart';
import '../data/character_repository.dart';

/// Widget that displays the current character and allows switching between characters.
///
/// Used in the AppBar to show the active character's portrait and name.
/// Tapping opens a menu to switch characters or add new ones.
class CharacterSelector extends ConsumerWidget {
  const CharacterSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final allCharacters = ref.watch(allCharactersProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildAddCharacterButton(context);
        }
        return _buildCharacterButton(
          context,
          ref,
          character,
          allCharacters.valueOrNull ?? [],
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _buildAddCharacterButton(context),
    );
  }

  Widget _buildAddCharacterButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_add),
      tooltip: 'Add Character',
      onPressed: () => context.push(AppRoutes.addCharacter),
    );
  }

  Widget _buildCharacterButton(
    BuildContext context,
    WidgetRef ref,
    Character activeCharacter,
    List<Character> allCharacters,
  ) {
    return PopupMenuButton<int>(
      tooltip: 'Switch Character',
      offset: const Offset(0, 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CharacterAvatar(
              portraitUrl: activeCharacter.portraitUrl,
              size: 32,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activeCharacter.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  activeCharacter.corporationName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
      itemBuilder: (context) => [
        // List all characters.
        ...allCharacters.map((character) => PopupMenuItem<int>(
              value: character.characterId,
              child: Row(
                children: [
                  _CharacterAvatar(
                    portraitUrl: character.portraitUrl,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(character.name),
                        Text(
                          character.corporationName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (character.characterId == activeCharacter.characterId)
                    Icon(
                      Icons.check,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            )),
        const PopupMenuDivider(),
        // Add character option.
        const PopupMenuItem<int>(
          value: -1, // Special value for add character.
          child: Row(
            children: [
              Icon(Icons.person_add),
              SizedBox(width: 12),
              Text('Add Character'),
            ],
          ),
        ),
      ],
      onSelected: (characterId) {
        if (characterId == -1) {
          context.push(AppRoutes.addCharacter);
        } else {
          ref
              .read(characterRepositoryProvider)
              .setActiveCharacter(characterId);
        }
      },
    );
  }
}

/// Circular avatar showing a character's portrait.
class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({
    required this.portraitUrl,
    required this.size,
  });

  final String portraitUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: portraitUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.person,
            size: size * 0.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// A larger character card for displaying in lists or grids.
class CharacterCard extends ConsumerWidget {
  const CharacterCard({
    required this.character,
    this.isActive = false,
    this.onTap,
    super.key,
  });

  final Character character;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _CharacterAvatar(
                portraitUrl: character.portraitUrl,
                size: 56,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            character.name,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Active',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      character.corporationName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (character.allianceName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        character.allianceName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
