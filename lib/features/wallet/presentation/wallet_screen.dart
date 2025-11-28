import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../characters/data/character_providers.dart';
import '../../characters/presentation/character_selector.dart';
import '../data/wallet_providers.dart';
import '../data/wallet_repository.dart';

/// Screen displaying the character's wallet balance and transaction journal.
///
/// Shows the current ISK balance prominently and a scrollable list
/// of recent transactions with color coding for income/expenses.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider).valueOrNull;
    final walletJournal = ref.watch(walletJournalProvider);
    final walletBalance = ref.watch(walletBalanceProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          if (activeCharacter != null)
            RefreshAppBarAction(
              onRefresh: () => _refreshWallet(ref, activeCharacter.characterId),
            ),
          if (isMobile) const CharacterSelector(),
        ],
      ),
      body: activeCharacter == null
          ? _buildNoCharacterState(context)
          : RefreshIndicator(
              onRefresh: () => _refreshWallet(ref, activeCharacter.characterId),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Balance header.
                  SliverToBoxAdapter(
                    child: _buildBalanceHeader(context, ref, walletBalance),
                  ),

                  // Journal list.
                  walletJournal.when(
                    data: (journal) => journal.isEmpty
                        ? SliverFillRemaining(
                            child: _buildEmptyJournalState(context),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _WalletJournalItem(
                                entry: journal[index],
                              ),
                              childCount: journal.length,
                            ),
                          ),
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stack) => SliverFillRemaining(
                      child: _buildErrorState(context, ref, error),
                    ),
                  ),

                  // Bottom padding.
                  const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<double?> balanceAsync,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wallet Balance',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          balanceAsync.when(
            data: (balance) => Text(
              balance != null ? formatIsk(balance) : 'No balance data',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            loading: () => Text(
              'Loading...',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            error: (_, __) => Text(
              'Error loading balance',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
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
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Character Selected',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to view your wallet.',
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

  Widget _buildEmptyJournalState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Transactions',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Your wallet journal is empty.\nTransactions will appear here.',
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

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);
    final activeCharacter = ref.watch(activeCharacterProvider).valueOrNull;

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
              'Failed to Load Wallet',
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
            if (activeCharacter != null)
              FilledButton.icon(
                onPressed: () =>
                    _refreshWallet(ref, activeCharacter.characterId),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshWallet(WidgetRef ref, int characterId) async {
    final repository = ref.read(walletRepositoryProvider);
    await Future.wait([
      repository.refreshWalletBalance(characterId),
      repository.refreshWalletJournal(characterId),
    ]);
    // Invalidate the balance provider to refresh.
    ref.invalidate(walletBalanceProvider);
  }
}

/// Widget displaying a single wallet journal entry.
class _WalletJournalItem extends StatelessWidget {
  const _WalletJournalItem({required this.entry});

  final WalletJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = entry.amount >= 0;
    final amountColor =
        isIncome ? Colors.green.shade600 : Colors.red.shade600;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Transaction type icon.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isIncome
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: amountColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Transaction details.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference type (formatted).
                  Text(
                    formatSnakeCase(entry.refType),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Description or date.
                  Text(
                    entry.description ?? _formatDate(entry.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Amount.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isIncome ? '+' : ''}${formatIskCompact(entry.amount)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(entry.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Formats a DateTime into a short date string.
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(date); // "3:45 PM"
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.EEEE().format(date); // "Monday"
    } else {
      return DateFormat.MMMd().format(date); // "Jan 15"
    }
  }
}
