import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../../features/characters/presentation/widgets/character_content_grid.dart';
import '../auth/auth_providers.dart';
import '../config/eve_config.dart';
import '../theme/eve_colors.dart';
import '../widgets/character_header_bar.dart';
import '../widgets/character_portrait_panel.dart';
import '../widgets/eve_card.dart';
import '../widgets/space_background.dart';
import 'window_types.dart';

/// Standalone characters screen for sub-windows.
///
/// Layout:
/// - Character header bar (switcher, add button)
/// - Row with split panels:
///   - Left panel (~40%): Character portrait with info overlay
///   - Right panel (~60%): Multi-column card grid
///
/// This matches EVE Online's character sheet design with portrait panel
/// and efficient card-based information display.
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
      backgroundColor: EveColors.darkBackground,
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
            : characters.when(
                data: (chars) {
                  if (chars.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return Column(
                    children: [
                      // Character header bar with switcher and add button
                      CharacterHeaderBar(
                        windowType: WindowType.characters,
                        onAddCharacter: () =>
                            setState(() => _showAddCharacter = true),
                        onRemoveCharacter: (characterId) =>
                            _removeCharacter(context, characterId),
                      ),

                      // Split panel content
                      Expanded(
                        child: activeCharacter.value != null
                            ? _buildSplitPanelContent(
                                context,
                                activeCharacter.value!,
                              )
                            : _buildNoCharacterState(context),
                      ),
                    ],
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
                        const Icon(Icons.error_outline,
                            size: 64, color: EveColors.error),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load characters',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Builds the split panel layout (portrait panel + card grid).
  Widget _buildSplitPanelContent(BuildContext context, character) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left panel: Character portrait with info overlay (~40%)
        Expanded(
          flex: 40,
          child: CharacterPortraitPanel(
            character: character,
          ),
        ),

        // Right panel: Multi-column card grid (~60%)
        const Expanded(
          flex: 60,
          child: CharacterContentGrid(),
        ),
      ],
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
                onPressed: () => setState(() => _showAddCharacter = true),
                icon: const Icon(Icons.add),
                label: const Text('Add Character'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Select a character from the header',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeCharacter(BuildContext context, int characterId) async {
    final character = ref.read(allCharactersProvider).value?.firstWhere(
          (c) => c.characterId == characterId,
          orElse: () => throw Exception('Character not found'),
        );

    if (character == null) return;

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

    if (confirmed == true && context.mounted) {
      await ref
          .read(characterRepositoryProvider)
          .deleteCharacter(characterId);
    }
  }
}

/// Placeholder for employment history tab.
///
/// Will show character's employment history (previous corporations).
class _HistoryTabPlaceholder extends StatelessWidget {
  const _HistoryTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'Employment History',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming soon',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(153),
                fontStyle: FontStyle.italic,
              ),
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
            ...[...EveConfig.phase1Scopes, ...EveConfig.phase2FleetScopes]
                .map((scope) => Padding(
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
