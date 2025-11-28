import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../characters/data/character_providers.dart';
import '../../characters/data/character_repository.dart';
import '../../characters/presentation/character_selector.dart';
import '../../skills/data/skill_providers.dart';
import '../../skills/data/skill_repository.dart';
import '../../wallet/data/wallet_providers.dart';
import '../../wallet/data/wallet_repository.dart';

/// Dashboard screen showing an overview of the active character.
///
/// Displays:
/// - Character card with portrait, name, and corporation
/// - Wallet balance
/// - Currently training skill
/// - Skill queue preview (next 3 skills)
/// - Recent wallet transactions
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final walletBalance = ref.watch(walletBalanceProvider);
    final currentTraining = ref.watch(currentTrainingProvider);
    final skillPreview = ref.watch(skillQueuePreviewProvider);
    final walletJournal = ref.watch(walletJournalProvider);

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // Extract characterId for refresh action (null when no character).
    final characterId = activeCharacter.valueOrNull?.characterId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (characterId != null)
            RefreshAppBarAction(
              onRefresh: () => _refreshAll(ref, characterId),
            ),
          if (isMobile) const CharacterSelector(),
        ],
      ),
      body: activeCharacter.when(
        data: (character) {
          if (character == null) {
            return _buildNoCharacterState(context);
          }

          return RefreshIndicator(
            onRefresh: () => _refreshAll(ref, character.characterId),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Character card.
                _CharacterCard(character: character),
                const SizedBox(height: 16),

                // Wallet balance card.
                _WalletBalanceCard(balance: walletBalance),
                const SizedBox(height: 16),

                // Currently training card.
                _CurrentTrainingCard(entry: currentTraining),
                const SizedBox(height: 16),

                // Skill queue preview.
                _SkillQueuePreviewCard(
                  skills: skillPreview,
                  onViewAll: () => context.go(AppRoutes.skills),
                ),
                const SizedBox(height: 16),

                // Recent transactions preview.
                _RecentTransactionsCard(
                  journal: walletJournal,
                  onViewAll: () => context.go(AppRoutes.wallet),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }

  Future<void> _refreshAll(WidgetRef ref, int characterId) async {
    // Refresh all data in parallel.
    await Future.wait([
      ref.read(characterRepositoryProvider).refreshCharacter(characterId),
      ref.read(skillRepositoryProvider).refreshSkillQueue(characterId),
      ref.read(walletRepositoryProvider).refreshWalletBalance(characterId),
      ref.read(walletRepositoryProvider).refreshWalletJournal(characterId),
    ]);

    // Invalidate providers to refresh UI.
    ref.invalidate(walletBalanceProvider);
  }
}

/// Card displaying the active character's info.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Character portrait.
            CircleAvatar(
              radius: 32,
              backgroundImage: NetworkImage(
                'https://images.evetech.net/characters/${character.characterId}/portrait?size=128',
              ),
            ),
            const SizedBox(width: 16),

            // Character info.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
    );
  }
}

/// Card displaying the wallet balance.
class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance});

  final AsyncValue<double?> balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 20,
                  color: theme.colorScheme.primary,
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
                  color: theme.colorScheme.primary,
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
      ),
    );
  }
}

/// Card displaying the currently training skill.
class _CurrentTrainingCard extends StatelessWidget {
  const _CurrentTrainingCard({required this.entry});

  final SkillQueueEntry? entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              Text(
                'Skill #${entry!.skillId}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Training to Level ${entry!.finishedLevel}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (entry!.finishDate != null) ...[
                const SizedBox(height: 8),
                _buildTimeRemaining(context, entry!.finishDate!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRemaining(BuildContext context, DateTime finishDate) {
    final theme = Theme.of(context);
    final remaining = finishDate.difference(DateTime.now());

    if (remaining.isNegative) {
      return Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          formatDuration(remaining),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Card showing a preview of the skill queue.
class _SkillQueuePreviewCard extends StatelessWidget {
  const _SkillQueuePreviewCard({
    required this.skills,
    required this.onViewAll,
  });

  final List<SkillQueueEntry> skills;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.queue,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Skill Queue',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
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
              ...skills.map((entry) => _buildSkillRow(context, entry)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillRow(BuildContext context, SkillQueueEntry entry) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: entry.queuePosition == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Text(
                '${entry.queuePosition + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: entry.queuePosition == 0
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Skill #${entry.skillId} → Level ${entry.finishedLevel}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing recent wallet transactions.
class _RecentTransactionsCard extends StatelessWidget {
  const _RecentTransactionsCard({
    required this.journal,
    required this.onViewAll,
  });

  final AsyncValue<List<WalletJournalEntry>> journal;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Transactions',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
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
                // Show first 3 transactions.
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
      ),
    );
  }

  Widget _buildTransactionRow(BuildContext context, WalletJournalEntry entry) {
    final theme = Theme.of(context);
    final isIncome = entry.amount >= 0;
    final amountColor =
        isIncome ? Colors.green.shade600 : Colors.red.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
            color: amountColor,
          ),
          const SizedBox(width: 8),
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
