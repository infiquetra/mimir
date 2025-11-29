import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../features/characters/data/character_providers.dart';
import '../../features/characters/data/character_repository.dart';
import '../../features/skills/data/skill_providers.dart';
import '../../features/skills/data/skill_repository.dart';
import '../../features/wallet/data/wallet_providers.dart';
import '../../features/wallet/data/wallet_repository.dart';
import '../database/app_database.dart';
import '../sde/sde_providers.dart';
import '../theme/eve_colors.dart';
import '../utils/formatters.dart';
import '../widgets/eve_card.dart';
import '../widgets/eve_skill_icon.dart';
import '../widgets/space_background.dart';

/// Standalone dashboard screen for sub-windows.
///
/// This is a simplified version of the main dashboard that:
/// - Uses regular providers (directly accesses database)
/// - Removes "View All" navigation buttons (standalone windows)
/// - Includes character selector for switching characters
class StandaloneDashboardScreen extends ConsumerWidget {
  const StandaloneDashboardScreen({super.key});

  int _getColumnCount(double width) {
    if (width < 600) return 1;
    if (width < 900) return 2;
    return 2;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final walletBalance = ref.watch(walletBalanceProvider);
    final currentTraining = ref.watch(currentTrainingProvider);
    final skillPreview = ref.watch(skillQueuePreviewProvider);
    final walletJournal = ref.watch(walletJournalProvider);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final columnCount = _getColumnCount(screenWidth);

    final characterId = activeCharacter.valueOrNull?.characterId;

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacter.when(
          data: (character) {
            if (character == null) {
              return _buildNoCharacterState(context);
            }

            return RefreshIndicator(
              onRefresh: () => _refreshAll(ref, character.characterId),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columnCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childCount: 4,
                      itemBuilder: (context, index) {
                        switch (index) {
                          case 0:
                            return _WalletBalanceCard(balance: walletBalance);
                          case 1:
                            return _CurrentTrainingCard(entry: currentTraining);
                          case 2:
                            return _SkillQueuePreviewCard(skills: skillPreview);
                          case 3:
                            return _RecentTransactionsCard(journal: walletJournal);
                          default:
                            return const SizedBox.shrink();
                        }
                      },
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
                'No Character Selected',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Use the character selector to choose a character,\nor open the Characters window to add one.',
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
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshAll(WidgetRef ref, int characterId) async {
    await Future.wait([
      ref.read(characterRepositoryProvider).refreshCharacter(characterId),
      ref.read(skillRepositoryProvider).refreshSkillQueue(characterId),
      ref.read(walletRepositoryProvider).refreshWalletBalance(characterId),
      ref.read(walletRepositoryProvider).refreshWalletJournal(characterId),
    ]);
    ref.invalidate(walletBalanceProvider);
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance});

  final AsyncValue<double?> balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EveCard(
      glowColor: EveColors.eveSecondary,
      glowIntensity: 0.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 20,
                color: EveColors.eveSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Wallet Balance',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          balance.when(
            data: (value) => Text(
              value != null ? formatIsk(value) : 'No data',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: EveColors.eveSecondary,
              ),
            ),
            loading: () => Text(
              'Loading...',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            error: (_, __) => Text(
              'Error',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentTrainingCard extends ConsumerWidget {
  const _CurrentTrainingCard({required this.entry});

  final SkillQueueEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skillNameAsync =
        entry != null ? ref.watch(skillNameProvider(entry!.skillId)) : null;

    return EveCard(
      glowColor: EveColors.evePrimary,
      glowIntensity: entry != null ? 0.25 : 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.school,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Currently Training',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (entry == null)
            Text(
              'No skill in training',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Row(
              children: [
                EveSkillIcon(
                  typeId: entry!.skillId,
                  size: 48,
                  showBorder: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      skillNameAsync!.when(
                        data: (skillName) => Text(
                          skillName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        loading: () => Container(
                          height: 24,
                          width: 150,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        error: (_, __) => Text(
                          'Skill #${entry!.skillId}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Training to Level ${entry!.finishedLevel}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (entry!.finishDate != null) ...[
              const SizedBox(height: 12),
              _buildTimeRemaining(context, entry!.finishDate!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRemaining(BuildContext context, DateTime finishDate) {
    final theme = Theme.of(context);
    final remaining = finishDate.difference(DateTime.now());

    if (remaining.isNegative) {
      return Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: EveColors.success),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: EveColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final startDate = entry!.startDate;
    if (startDate != null) {
      final totalDuration = finishDate.difference(startDate);
      final elapsed = DateTime.now().difference(startDate);
      final progress = (elapsed.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                formatDuration(remaining),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: EveColors.evePrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: EveColors.darkSurfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(EveColors.evePrimary),
              minHeight: 6,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          formatDuration(remaining),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: EveColors.evePrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Skill queue preview without "View All" button.
class _SkillQueuePreviewCard extends ConsumerWidget {
  const _SkillQueuePreviewCard({required this.skills});

  final List<SkillQueueEntry> skills;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return EveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Skill Queue', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (skills.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No skills in queue',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...skills.map((entry) => _buildSkillRow(context, ref, entry)),
        ],
      ),
    );
  }

  Widget _buildSkillRow(BuildContext context, WidgetRef ref, SkillQueueEntry entry) {
    final theme = Theme.of(context);
    final skillNameAsync = ref.watch(skillNameProvider(entry.skillId));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          EveSkillIcon(typeId: entry.skillId, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: skillNameAsync.when(
              data: (skillName) => Text(
                '$skillName → Level ${entry.finishedLevel}',
                style: theme.textTheme.bodyMedium,
              ),
              loading: () => Container(
                height: 16,
                width: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              error: (_, __) => Text(
                'Skill #${entry.skillId} → Level ${entry.finishedLevel}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: entry.queuePosition == 0
                  ? EveColors.evePrimary.withAlpha(51)
                  : EveColors.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${entry.queuePosition + 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: entry.queuePosition == 0
                    ? EveColors.evePrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent transactions without "View All" button.
class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({required this.journal});

  final AsyncValue<List<WalletJournalEntry>> journal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Recent Transactions', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          journal.when(
            data: (entries) {
              if (entries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No transactions',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: entries
                    .take(3)
                    .map((entry) => _buildTransactionRow(context, entry))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Error loading transactions',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, WalletJournalEntry entry) {
    final theme = Theme.of(context);
    final isIncome = entry.amount >= 0;
    final amountColor = isIncome ? EveColors.iskPositive : EveColors.iskNegative;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: amountColor.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              size: 16,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              formatSnakeCase(entry.refType),
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${isIncome ? '+' : ''}${formatIskCompact(entry.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
