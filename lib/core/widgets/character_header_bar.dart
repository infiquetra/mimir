import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../../features/skills/data/skill_repository.dart';
import '../../features/wallet/data/wallet_repository.dart';
import '../database/app_database.dart' show Character;
import '../router/app_router.dart';
import '../theme/eve_colors.dart';
import '../window/window_types.dart';
import 'character_avatar.dart';

/// Maximum number of non-active characters to show before overflow.
const int _maxVisibleCharacters = 4;

/// Full-width header bar displaying character information.
///
/// Shows the active character prominently on the left with name and corporation,
/// and non-active characters as smaller clickable avatars on the right.
///
/// On desktop: Larger avatars (48px active, 32px others)
/// On mobile: Compact avatars (40px active, 28px others)
///
/// When no character is logged in, shows an "Add Character" button.
///
/// When [windowType] is provided (Dashboard/Skills/Wallet), shows a refresh
/// button instead of the "Add Character" icon button.
class CharacterHeaderBar extends ConsumerWidget {
  const CharacterHeaderBar({
    this.windowType,
    super.key,
  });

  /// The type of window this header is shown in, determines refresh behavior.
  final WindowType? windowType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final allCharacters = ref.watch(allCharactersProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;

    return Container(
      height: isDesktop ? 64 : 56,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: EveColors.darkSurface,
        border: Border(
          bottom: BorderSide(
            color: EveColors.evePrimary.withAlpha(26),
            width: 1,
          ),
        ),
      ),
      child: activeCharacter.when(
        data: (character) {
          if (character == null) {
            return _AddCharacterSection(isDesktop: isDesktop);
          }
          return _buildCharacterRow(
            context,
            ref,
            character,
            allCharacters.value ?? [],
            isDesktop,
          );
        },
        loading: () => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => _AddCharacterSection(isDesktop: isDesktop),
      ),
    );
  }

  Widget _buildCharacterRow(
    BuildContext context,
    WidgetRef ref,
    Character activeCharacter,
    List<Character> allCharacters,
    bool isDesktop,
  ) {
    // Filter out active character for the switcher row.
    final otherCharacters = allCharacters
        .where((c) => c.characterId != activeCharacter.characterId)
        .toList();

    return Row(
      children: [
        // Active character section (left).
        _ActiveCharacterSection(
          character: activeCharacter,
          isDesktop: isDesktop,
        ),
        const Spacer(),
        // Other characters switcher (right).
        if (otherCharacters.isNotEmpty)
          _CharacterSwitcherRow(
            characters: otherCharacters,
            isDesktop: isDesktop,
            onCharacterTap: (characterId) {
              ref
                  .read(characterRepositoryProvider)
                  .setActiveCharacter(characterId);
            },
          ),
        // Refresh button (when windowType is provided) or add character button.
        if (windowType != null)
          _RefreshIconButton(
            isDesktop: isDesktop,
            windowType: windowType!,
            characterId: activeCharacter.characterId,
          )
        else
          _AddCharacterIconButton(isDesktop: isDesktop),
      ],
    );
  }
}

/// Left section showing the active character with avatar, name, and corporation.
class _ActiveCharacterSection extends StatelessWidget {
  const _ActiveCharacterSection({
    required this.character,
    required this.isDesktop,
  });

  final Character character;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarSize = isDesktop ? CharacterAvatarSize.large : CharacterAvatarSize.medium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active avatar with glow.
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(128),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(51),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CharacterAvatar(
            portraitUrl: character.portraitUrl,
            size: avatarSize,
          ),
        ),
        const SizedBox(width: 12),
        // Name and corporation.
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              character.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              character.corporationName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Row of non-active character avatars with overflow handling.
class _CharacterSwitcherRow extends StatelessWidget {
  const _CharacterSwitcherRow({
    required this.characters,
    required this.isDesktop,
    required this.onCharacterTap,
  });

  final List<Character> characters;
  final bool isDesktop;
  final void Function(int characterId) onCharacterTap;

  @override
  Widget build(BuildContext context) {
    final visibleCharacters = characters.take(_maxVisibleCharacters).toList();
    final overflowCount = characters.length - _maxVisibleCharacters;
    final avatarSize = isDesktop ? CharacterAvatarSize.small : CharacterAvatarSize.small;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visible character avatars.
        ...visibleCharacters.map((character) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: StyledCharacterAvatar(
                portraitUrl: character.portraitUrl,
                size: avatarSize,
                isActive: false,
                tooltip: character.name,
                onTap: () => onCharacterTap(character.characterId),
              ),
            )),
        // Overflow badge.
        if (overflowCount > 0)
          _OverflowBadge(
            count: overflowCount,
            hiddenCharacters: characters.skip(_maxVisibleCharacters).toList(),
            onCharacterTap: onCharacterTap,
            isDesktop: isDesktop,
          ),
      ],
    );
  }
}

/// Badge showing "+N" with popup menu for hidden characters.
class _OverflowBadge extends StatelessWidget {
  const _OverflowBadge({
    required this.count,
    required this.hiddenCharacters,
    required this.onCharacterTap,
    required this.isDesktop,
  });

  final int count;
  final List<Character> hiddenCharacters;
  final void Function(int characterId) onCharacterTap;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = isDesktop ? 32.0 : 28.0;

    return PopupMenuButton<int>(
      tooltip: '$count more characters',
      offset: const Offset(0, 40),
      itemBuilder: (context) => hiddenCharacters
          .map((character) => PopupMenuItem<int>(
                value: character.characterId,
                child: Row(
                  children: [
                    CharacterAvatar(
                      portraitUrl: character.portraitUrl,
                      size: CharacterAvatarSize.small,
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
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
      onSelected: onCharacterTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(77),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '+$count',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// "Add Character" section shown when no character is logged in.
class _AddCharacterSection extends StatelessWidget {
  const _AddCharacterSection({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: isDesktop ? 48 : 40,
          height: isDesktop ? 48 : 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: theme.colorScheme.outline.withAlpha(77),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.person_outline,
            size: isDesktop ? 28 : 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No Character',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Add a character to get started',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
              ),
            ),
          ],
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: () => context.push(AppRoutes.addCharacter),
          icon: const Icon(Icons.person_add, size: 18),
          label: const Text('Add Character'),
        ),
      ],
    );
  }
}

/// Small "+" button to add more characters.
class _AddCharacterIconButton extends StatelessWidget {
  const _AddCharacterIconButton({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = isDesktop ? 32.0 : 28.0;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Add Character',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.addCharacter),
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: theme.colorScheme.outline.withAlpha(77),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.add,
                size: size * 0.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Refresh button that calls the appropriate refresh logic based on window type.
class _RefreshIconButton extends ConsumerWidget {
  const _RefreshIconButton({
    required this.isDesktop,
    required this.windowType,
    required this.characterId,
  });

  final bool isDesktop;
  final WindowType windowType;
  final int characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final size = isDesktop ? 32.0 : 28.0;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: 'Refresh',
        child: InkWell(
          onTap: () => _handleRefresh(ref),
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: theme.colorScheme.outline.withAlpha(77),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.refresh,
              size: size * 0.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRefresh(WidgetRef ref) async {
    switch (windowType) {
      case WindowType.dashboard:
        // Refresh all: character, skills, wallet.
        final characterRepo = ref.read(characterRepositoryProvider);
        final skillRepo = ref.read(skillRepositoryProvider);
        final walletRepo = ref.read(walletRepositoryProvider);

        await Future.wait([
          characterRepo.refreshCharacter(characterId),
          skillRepo.refreshSkillQueue(characterId),
          walletRepo.refreshWalletBalance(characterId),
          walletRepo.refreshWalletJournal(characterId),
        ]);
        break;

      case WindowType.skills:
        // Refresh skill queue only.
        final skillRepo = ref.read(skillRepositoryProvider);
        await skillRepo.refreshSkillQueue(characterId);
        break;

      case WindowType.wallet:
        // Refresh wallet balance and journal.
        final walletRepo = ref.read(walletRepositoryProvider);
        await Future.wait([
          walletRepo.refreshWalletBalance(characterId),
          walletRepo.refreshWalletJournal(characterId),
        ]);
        break;

      case WindowType.characters:
      case WindowType.settings:
      case WindowType.main:
      case WindowType.onboarding:
        // No refresh for these windows.
        break;
    }
  }
}
