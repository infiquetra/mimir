import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../../features/dashboard/data/dashboard_providers.dart';
import '../../features/dashboard/presentation/widgets/cards/combat_stats_card.dart';
import '../../features/dashboard/presentation/widgets/cards/combined_wealth_card.dart';
import '../../features/dashboard/presentation/widgets/cards/fleet_status_card.dart';
import '../../features/dashboard/presentation/widgets/cards/quick_actions_card.dart';
import '../../features/dashboard/presentation/widgets/cards/training_overview_card.dart';
import '../../features/dashboard/presentation/widgets/cards/training_timeline_card.dart';
import '../../features/dashboard/presentation/widgets/cards/wallet_trends_card.dart';
import '../../features/skills/data/skill_repository.dart';
import '../../features/wallet/data/wallet_repository.dart';
import '../theme/eve_colors.dart';
import '../widgets/eve_card.dart';
import '../widgets/space_background.dart';

/// Standalone dashboard screen for sub-windows.
///
/// This is a simplified version of the main dashboard that:
/// - Shows multi-character overview (aggregated data across ALL characters)
/// - Removes "View All" navigation buttons (standalone windows)
/// - Includes character selector for switching active character
class StandaloneDashboardScreen extends ConsumerStatefulWidget {
  const StandaloneDashboardScreen({super.key});

  @override
  ConsumerState<StandaloneDashboardScreen> createState() =>
      _StandaloneDashboardScreenState();
}

class _StandaloneDashboardScreenState
    extends ConsumerState<StandaloneDashboardScreen> {
  int _getColumnCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final characters = ref.watch(allCharactersProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnCount = _getColumnCount(screenWidth);

    return Scaffold(
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
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorState(context, error),
        ),
      ),
    );
  }

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
                'Open the Characters window to add a character.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
}
