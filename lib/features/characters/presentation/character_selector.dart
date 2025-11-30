import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/database/app_database.dart' show Character, isSubWindow;
import '../../../core/router/app_router.dart';
import '../data/character_providers.dart';
import '../data/character_repository.dart';

/// Widget that displays the current character and allows switching between characters.
///
/// Used in the AppBar to show the active character's portrait and name.
/// Tapping opens a menu to switch characters or add new ones.
///
/// Set [compact] to true to show only the avatar (for narrow spaces like nav rails).
class CharacterSelector extends ConsumerWidget {
  const CharacterSelector({super.key, this.compact = false});

  /// When true, only shows the avatar without name/corporation text.
  final bool compact;

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
          allCharacters.value ?? [],
          compact,
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
    bool isCompact,
  ) {
    return PopupMenuButton<int>(
      tooltip: 'Switch Character',
      offset: isCompact ? const Offset(80, 0) : const Offset(0, 48),
      child: isCompact
          ? _buildCompactChild(context, activeCharacter)
          : _buildFullChild(context, activeCharacter),
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
        // Remove character option.
        PopupMenuItem<int>(
          value: -2, // Special value for remove character.
          child: Row(
            children: [
              Icon(Icons.person_remove,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Remove Character',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (characterId) async {
        if (characterId == -1) {
          context.push(AppRoutes.addCharacter);
        } else if (characterId == -2) {
          // Show confirmation dialog for removing the active character.
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove Character'),
              content: Text(
                'Are you sure you want to remove ${activeCharacter.name}? '
                'This will revoke access tokens and remove the character from Mimir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await ref
                .read(authControllerProvider.notifier)
                .logout(activeCharacter.characterId);
          }
        } else {
          ref
              .read(characterRepositoryProvider)
              .setActiveCharacter(characterId);
        }
      },
    );
  }

  /// Builds a compact child widget (avatar only) for narrow spaces.
  Widget _buildCompactChild(BuildContext context, Character character) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(128),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(51),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: _CharacterAvatar(
        portraitUrl: character.portraitUrl,
        size: 40,
      ),
    );
  }

  /// Builds the full child widget with avatar, name, and dropdown indicator.
  Widget _buildFullChild(BuildContext context, Character character) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CharacterAvatar(
            portraitUrl: character.portraitUrl,
            size: 32,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                character.corporationName,
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
    );
  }
}

/// Circular avatar showing a character's portrait.
///
/// Uses [CachedNetworkImage] for disk caching in the main window,
/// or [Image.network] for sub-windows that can't access native plugins.
class _CharacterAvatar extends StatelessWidget {
  const _CharacterAvatar({
    required this.portraitUrl,
    required this.size,
  });

  final String portraitUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    // Use Image.network for sub-windows (CachedNetworkImage uses path_provider).
    final imageWidget = isSubWindow
        ? Image.network(
            portraitUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return placeholder;
            },
            errorBuilder: (context, error, stackTrace) => placeholder,
          )
        : CachedNetworkImage(
            imageUrl: portraitUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => placeholder,
          );

    return ClipOval(child: imageWidget);
  }
}

/// Simple character avatar display (without dropdown menu).
///
/// Use this in sub-window screens that only need to show the character
/// portrait without the ability to switch or add characters.
class CharacterAvatarDisplay extends ConsumerWidget {
  const CharacterAvatarDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return const SizedBox(width: 40, height: 40);
        }
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withAlpha(51),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: _CharacterAvatar(
            portraitUrl: character.portraitUrl,
            size: 32,
          ),
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(width: 40, height: 40),
    );
  }
}

/// Horizontal row of character avatars for sub-windows.
///
/// Shows all characters as clickable avatars in a horizontal row.
/// The active character is highlighted with a glowing border.
/// Tapping a non-active character switches to that character.
///
/// Use this in sub-window AppBar actions for character switching.
class SubWindowCharacterSwitcher extends ConsumerWidget {
  const SubWindowCharacterSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final allCharacters = ref.watch(allCharactersProvider);

    return allCharacters.when(
      data: (characters) {
        if (characters.isEmpty) {
          return const SizedBox.shrink();
        }

        final activeId = activeCharacter.value?.characterId;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: characters.map((character) {
            final isActive = character.characterId == activeId;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _CharacterSwitchButton(
                character: character,
                isActive: isActive,
                onTap: isActive
                    ? null
                    : () => ref
                        .read(characterRepositoryProvider)
                        .setActiveCharacter(character.characterId),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Individual character switch button with active state styling.
class _CharacterSwitchButton extends StatelessWidget {
  const _CharacterSwitchButton({
    required this.character,
    required this.isActive,
    this.onTap,
  });

  final Character character;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: character.name,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary
                  : Colors.transparent,
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
            child: _CharacterAvatar(
              portraitUrl: character.portraitUrl,
              size: 32,
            ),
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
