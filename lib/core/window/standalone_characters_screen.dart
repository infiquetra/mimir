import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../../features/characters/presentation/tabs/character_tab.dart';
import '../../features/characters/presentation/tabs/interactions_tab.dart';
import '../../features/characters/presentation/tabs/overview_tab.dart';
import '../auth/auth_providers.dart';
import '../config/eve_config.dart';
import '../database/app_database.dart';
import '../theme/eve_colors.dart';
import '../widgets/eve_card.dart';
import '../widgets/space_background.dart';

/// Standalone characters screen for sub-windows.
///
/// This screen combines:
/// - Character management (add/remove/switch) in a sidebar
/// - Enhanced character details (Overview/Character/Interactions tabs)
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
    extends ConsumerState<StandaloneCharactersScreen>
    with SingleTickerProviderStateMixin {
  bool _showAddCharacter = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

                  return Row(
                    children: [
                      // Character sidebar
                      Container(
                        width: 240,
                        decoration: BoxDecoration(
                          color: EveColors.darkSurface,
                          border: Border(
                            right: BorderSide(
                              color: EveColors.evePrimary.withAlpha(51),
                            ),
                          ),
                        ),
                        child: _CharacterSidebar(
                          characters: chars,
                          activeCharacterId: activeCharacter.value?.characterId,
                          onAddCharacter: () =>
                              setState(() => _showAddCharacter = true),
                        ),
                      ),

                      // Enhanced character details tabs
                      Expanded(
                        child: Column(
                          children: [
                            Container(
                              color: EveColors.darkSurface,
                              child: TabBar(
                                controller: _tabController,
                                indicatorColor: EveColors.evePrimary,
                                labelColor: EveColors.evePrimary,
                                unselectedLabelColor:
                                    Colors.white.withAlpha(179),
                                tabs: const [
                                  Tab(
                                    icon: Icon(Icons.dashboard_outlined),
                                    text: 'Overview',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.person_outlined),
                                    text: 'Character',
                                  ),
                                  Tab(
                                    icon: Icon(Icons.people_outlined),
                                    text: 'Interactions',
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: activeCharacter.value != null
                                  ? TabBarView(
                                      controller: _tabController,
                                      children: const [
                                        OverviewTab(),
                                        CharacterTab(),
                                        InteractionsTab(),
                                      ],
                                    )
                                  : _buildNoCharacterState(context),
                            ),
                          ],
                        ),
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
            'Select a character from the sidebar',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact character sidebar for switching between characters.
class _CharacterSidebar extends ConsumerWidget {
  const _CharacterSidebar({
    required this.characters,
    required this.activeCharacterId,
    required this.onAddCharacter,
  });

  final List<Character> characters;
  final int? activeCharacterId;
  final VoidCallback onAddCharacter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: characters.length + 1,
      itemBuilder: (context, index) {
        // Add character button as the last item
        if (index == characters.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AddCharacterButton(onTap: onAddCharacter),
          );
        }

        final character = characters[index];
        final isActive = character.characterId == activeCharacterId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CompactCharacterTile(
            character: character,
            isActive: isActive,
            onTap: () => _setActiveCharacter(ref, character.characterId),
            onRemove: () => _removeCharacter(context, ref, character),
          ),
        );
      },
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
      await ref
          .read(characterRepositoryProvider)
          .deleteCharacter(character.characterId);
    }
  }
}

/// Compact tile displaying a single character in the sidebar.
class _CompactCharacterTile extends StatelessWidget {
  const _CompactCharacterTile({
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
    return EveCard(
      glowColor: isActive ? EveColors.evePrimary : null,
      glowIntensity: isActive ? 0.3 : 0.0,
      padding: const EdgeInsets.all(8),
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
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://images.evetech.net/characters/${character.characterId}/portrait?size=64',
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Character info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    character.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isActive ? FontWeight.bold : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isActive)
                    Text(
                      'Active',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: EveColors.evePrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                ],
              ),
            ),

            // Remove button
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: EveColors.error.withAlpha(179),
              tooltip: 'Remove character',
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Button for adding a new character.
class _AddCharacterButton extends StatelessWidget {
  const _AddCharacterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EveCard(
      glowColor: EveColors.evePrimary,
      glowIntensity: 0.15,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Add Character',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: EveColors.evePrimary,
                      ),
                ),
              ),
            ],
          ),
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
