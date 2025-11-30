import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart' show WalletJournalEntry;
import '../../../core/theme/eve_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eve_card.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
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
    final activeCharacter = ref.watch(activeCharacterProvider).value;
    final walletJournal = ref.watch(walletJournalProvider);
    final walletBalance = ref.watch(walletBalanceProvider);

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacter == null
            ? _buildNoCharacterState(context)
            : RefreshIndicator(
                onRefresh: () =>
                    _refreshWallet(ref, activeCharacter.characterId),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Top padding for AppBar.
                    SliverPadding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top +
                            kToolbarHeight +
                            8,
                      ),
                    ),

                    // Balance header.
                    SliverToBoxAdapter(
                      child: _buildBalanceHeader(context, ref, walletBalance),
                    ),

                    // Section header for journal.
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                        child: Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: EveColors.evePrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
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
                        child: Center(
                          child: CircularProgressIndicator(
                            color: EveColors.evePrimary,
                          ),
                        ),
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
      ),
    );
  }

  Widget _buildBalanceHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<double?> balanceAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: EveCard(
        glowColor: EveColors.eveSecondary,
        glowIntensity: 0.5,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: EveColors.eveSecondary.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: EveColors.eveSecondary.withAlpha(77),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: EveColors.eveSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'ISK Balance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(179),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            balanceAsync.when(
              data: (balance) => Text(
                balance != null ? formatIsk(balance) : 'No balance data',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: EveColors.eveSecondary,
                  shadows: [
                    Shadow(
                      color: EveColors.eveSecondary.withAlpha(128),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              loading: () => Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withAlpha(128),
                ),
              ),
              error: (_, __) => const Text(
                'Error loading balance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: EveColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: Colors.white.withAlpha(128),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Character Selected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to view your wallet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyJournalState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.white.withAlpha(128),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Transactions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your wallet journal is empty.\nTransactions will appear here.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: EveColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Wallet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (activeCharacter != null)
              ElevatedButton.icon(
                onPressed: () =>
                    _refreshWallet(ref, activeCharacter.characterId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: EveColors.evePrimary,
                  foregroundColor: Colors.white,
                ),
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
    final isIncome = entry.amount >= 0;
    final amountColor = isIncome ? EveColors.success : EveColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: EveCard(
        glowColor: isIncome ? EveColors.success : null,
        glowIntensity: isIncome ? 0.15 : 0.0,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Transaction type icon.
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: amountColor.withAlpha(26),
                border: Border.all(
                  color: amountColor.withAlpha(77),
                  width: 1,
                ),
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: amountColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Transaction details.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference type (formatted).
                  Text(
                    formatSnakeCase(entry.refType),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Description or date.
                  Text(
                    entry.description ?? _formatDate(entry.date),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(128),
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(entry.date),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withAlpha(128),
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
