import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../auth/auth_providers.dart';
import '../config/eve_config.dart';
import '../database/app_database.dart';
import '../theme/eve_colors.dart';
import '../widgets/eve_card.dart';
import '../widgets/space_background.dart';

/// Standalone characters screen for sub-windows.
///
/// This screen allows users to:
/// - View all added characters
/// - Add new characters via OAuth
/// - Switch the active character
/// - Remove characters
///
/// Unlike the main app's character management, this is a full-featured
/// standalone screen that doesn't depend on go_router navigation.
class StandaloneCharactersScreen extends ConsumerStatefulWidget {
  const StandaloneCharactersScreen({super.key});

  @override
  ConsumerState<StandaloneCharactersScreen> createState() =>
      _StandaloneCharactersScreenState();
}

class _StandaloneCharactersScreenState
    extends ConsumerState<StandaloneCharactersScreen> {
  bool _showAddCharacter = false;

  @override
  Widget build(BuildContext context) {
    final characters = ref.watch(allCharactersProvider);
    final activeCharacter = ref.watch(activeCharacterProvider);
    final authState = ref.watch(authControllerProvider);

    // Auto-hide add character view on success
    if (authState.flowState == AuthFlowState.success && _showAddCharacter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(authControllerProvider.notifier).reset();
        setState(() => _showAddCharacter = false);
      });
    }

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: _showAddCharacter
            ? _AddCharacterView(
                authState: authState,
                onCancel: () {
                  ref.read(authControllerProvider.notifier).cancelAuth();
                  setState(() => _showAddCharacter = false);
                },
              )
            : _CharacterListView(
                characters: characters,
                activeCharacterId: activeCharacter.valueOrNull?.characterId,
                onAddCharacter: () => setState(() => _showAddCharacter = true),
              ),
      ),
    );
  }
}

/// View showing the list of characters.
class _CharacterListView extends ConsumerWidget {
  const _CharacterListView({
    required this.characters,
    required this.activeCharacterId,
    required this.onAddCharacter,
  });

  final AsyncValue<List<Character>> characters;
  final int? activeCharacterId;
  final VoidCallback onAddCharacter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return characters.when(
      data: (chars) {
        if (chars.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: chars.length + 1,
          itemBuilder: (context, index) {
            // Add character card as the last item
            if (index == chars.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AddCharacterCard(onTap: onAddCharacter),
              );
            }

            final character = chars[index];
            final isActive = character.characterId == activeCharacterId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CharacterTile(
                character: character,
                isActive: isActive,
                onTap: () => _setActiveCharacter(ref, character.characterId),
                onRemove: () => _removeCharacter(context, ref, character),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: EveColors.evePrimary),
      ),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: EveColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load characters',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EveCard(
          glowColor: EveColors.evePrimary,
          glowIntensity: 0.2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No Characters',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Add an EVE Online character to get started.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddCharacter,
                icon: const Icon(Icons.add),
                label: const Text('Add Character'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setActiveCharacter(WidgetRef ref, int characterId) async {
    await ref.read(characterRepositoryProvider).setActiveCharacter(characterId);
  }

  Future<void> _removeCharacter(
    BuildContext context,
    WidgetRef ref,
    Character character,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Character'),
        content: Text(
          'Are you sure you want to remove ${character.name}?\n\n'
          'This will remove the character from Mimir, but will not affect '
          'your EVE Online account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: EveColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(characterRepositoryProvider).deleteCharacter(character.characterId);
    }
  }
}

/// Tile displaying a single character.
class _CharacterTile extends StatelessWidget {
  const _CharacterTile({
    required this.character,
    required this.isActive,
    required this.onTap,
    required this.onRemove,
  });

  final Character character;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EveCard(
      glowColor: isActive ? EveColors.evePrimary : null,
      glowIntensity: isActive ? 0.3 : 0.0,
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          children: [
            // Character portrait
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(color: EveColors.evePrimary, width: 2)
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: EveColors.evePrimary.withAlpha(77),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(
                  'https://images.evetech.net/characters/${character.characterId}/portrait?size=128',
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Character info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          character.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: EveColors.evePrimary.withAlpha(51),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: EveColors.evePrimary,
                              fontWeight: FontWeight.bold,
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

            // Remove button
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: EveColors.error.withAlpha(179),
              tooltip: 'Remove character',
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// View for adding a new character via OAuth.
class _AddCharacterView extends ConsumerWidget {
  const _AddCharacterView({
    required this.authState,
    required this.onCancel,
  });

  final AuthState authState;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _buildContent(context, ref, theme),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ThemeData theme) {
    switch (authState.flowState) {
      case AuthFlowState.idle:
        return _buildIdleState(context, ref, theme);

      case AuthFlowState.awaitingCallback:
        return _buildAwaitingState(theme);

      case AuthFlowState.exchangingTokens:
        return _buildExchangingState(theme);

      case AuthFlowState.success:
        return _buildSuccessState(ref, theme);

      case AuthFlowState.error:
        return _buildErrorState(context, ref, theme);
    }
  }

  Widget _buildIdleState(BuildContext context, WidgetRef ref, ThemeData theme) {
    return EveCard(
      glowColor: EveColors.evePrimary,
      glowIntensity: 0.15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Add EVE Character',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect your EVE Online character to view your skill queue, wallet, and more.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          _buildScopesList(theme),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).startAuthFlow();
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign in with EVE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScopesList(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Requested Permissions',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...[...EveConfig.phase1Scopes, ...EveConfig.phase2FleetScopes].map((scope) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatScope(scope),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  String _formatScope(String scope) {
    final parts = scope.split('.');
    if (parts.length < 2) return scope;

    final action = parts[1]
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');

    return action;
  }

  Widget _buildAwaitingState(ThemeData theme) {
    return EveCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: EveColors.evePrimary),
          const SizedBox(height: 24),
          Text(
            'Waiting for Authorization',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Complete the sign-in process in your browser.\n'
            'This window will update automatically.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangingState(ThemeData theme) {
    return EveCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: EveColors.evePrimary),
          const SizedBox(height: 24),
          Text(
            'Completing Authentication',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            'Securing your connection...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(WidgetRef ref, ThemeData theme) {
    return EveCard(
      glowColor: EveColors.success,
      glowIntensity: 0.2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: EveColors.success,
          ),
          const SizedBox(height: 24),
          Text(
            'Character Added!',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(authControllerProvider.notifier).reset();
              onCancel();
            },
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return EveCard(
      glowColor: EveColors.error,
      glowIntensity: 0.15,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: EveColors.error,
          ),
          const SizedBox(height: 24),
          Text(
            'Authentication Failed',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            authState.errorMessage ?? 'An unknown error occurred.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16),
              FilledButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).reset();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card widget for adding a new character.
class _AddCharacterCard extends StatelessWidget {
  const _AddCharacterCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EveCard(
      glowColor: EveColors.evePrimary,
      glowIntensity: 0.15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: EveColors.evePrimary.withAlpha(26),
                  border: Border.all(
                    color: EveColors.evePrimary.withAlpha(77),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person_add,
                  color: EveColors.evePrimary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Character',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: EveColors.evePrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Authenticate with EVE Online',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward,
                color: EveColors.evePrimary.withAlpha(179),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
