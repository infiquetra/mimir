import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/eve_card.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import '../../characters/data/character_repository.dart';
import '../../skills/data/skill_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/dashboard_providers.dart';
import 'widgets/cards/combat_stats_card.dart';
import 'widgets/cards/combined_wealth_card.dart';
import 'widgets/cards/fleet_status_card.dart';
import 'widgets/cards/quick_actions_card.dart';
import 'widgets/cards/training_overview_card.dart';
import 'widgets/cards/training_timeline_card.dart';
import 'widgets/cards/wallet_trends_card.dart';

/// Dashboard screen showing multi-character overview.
///
/// Displays in a responsive masonry grid:
/// - Combined wealth across all characters
/// - Training overview with upcoming skill completions
/// - Quick actions for refreshing all data and alerts
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Calculate number of columns based on screen width.
  int _getColumnCount(double width) {
    if (width < 600) return 1; // Mobile: single column
    if (width < 900) return 2; // Tablet: two columns
    return 2; // Desktop: keep at 2 for better card sizing
  }

  /// Refresh all multi-character data.
  Future<void> _refreshAll() async {
    // Get all characters
    final characters = await ref.read(allCharactersProvider.future);

    // Invalidate all multi-character providers
    ref.invalidate(allCharacterBalancesProvider);
    ref.invalidate(allCharacterSkillQueuesProvider);

    // Refresh data for each character
    final characterRepo = ref.read(characterRepositoryProvider);
    final walletRepo = ref.read(walletRepositoryProvider);
    final skillRepo = ref.read(skillRepositoryProvider);

    for (final character in characters) {
      try {
        await Future.wait([
          characterRepo.refreshCharacter(character.characterId),
          walletRepo.refreshWalletBalance(character.characterId),
          walletRepo.refreshWalletJournal(character.characterId),
          skillRepo.refreshSkillQueue(character.characterId),
        ]);
      } catch (e) {
        // Continue refreshing other characters even if one fails
        debugPrint('Failed to refresh character ${character.characterId}: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final characters = ref.watch(allCharactersProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnCount = _getColumnCount(screenWidth);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Dashboard'),
        actions: [
          RefreshAppBarAction(
            onRefresh: _refreshAll,
          ),
        ],
      ),
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: characters.when(
          data: (chars) {
            if (chars.isEmpty) {
              return _buildNoCharacterState(context);
            }

            return RefreshIndicator(
              onRefresh: _refreshAll,
              child: CustomScrollView(
                slivers: [
                  // Top padding for app bar
                  SliverPadding(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top +
                          kToolbarHeight +
                          8,
                      left: 16,
                      right: 16,
                      bottom: 16,
                    ),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columnCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childCount: 7,
                      itemBuilder: (context, index) => _buildCard(index),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => _buildLoadingState(context),
          error: (error, stack) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  /// Build card at the given index.
  Widget _buildCard(int index) {
    switch (index) {
      case 0:
        return const CombinedWealthCard();
      case 1:
        return const TrainingOverviewCard();
      case 2:
        return const QuickActionsCard();
      case 3:
        return const FleetStatusCard();
      case 4:
        return const WalletTrendsCard();
      case 5:
        return const TrainingTimelineCard();
      case 6:
        return const CombatStatsCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
          left: 32,
          right: 32,
          bottom: 32,
        ),
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
                'Welcome to Mimir',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Add a character to get started.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.addCharacter),
                icon: const Icon(Icons.add),
                label: const Text('Add Character'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight,
        ),
        child: const CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
          left: 32,
          right: 32,
          bottom: 32,
        ),
        child: EveCard(
          glowColor: EveColors.error,
          glowIntensity: 0.2,
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
                'Failed to Load Dashboard',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _refreshAll,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
