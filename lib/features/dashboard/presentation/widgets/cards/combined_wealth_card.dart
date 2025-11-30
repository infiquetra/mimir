import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/character_avatar.dart';
import '../../../../characters/data/character_providers.dart';
import '../../../data/dashboard_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing combined wealth across all characters with
/// per-character breakdown.
///
/// Displays:
/// - Total ISK across all characters (large, centered)
/// - Visual breakdown for each character (avatar, name, bar, amount, %)
/// - Characters sorted by balance (highest first)
///
/// Handles loading, error, and empty states via [DashboardCard].
class CombinedWealthCard extends ConsumerWidget {
  const CombinedWealthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combinedWealthAsync = ref.watch(combinedWealthProvider);
    final balancesAsync = ref.watch(allCharacterBalancesProvider);
    final charactersAsync = ref.watch(allCharactersProvider);

    // Determine loading state
    final isLoading = combinedWealthAsync.isLoading ||
        balancesAsync.isLoading ||
        charactersAsync.isLoading;

    // Determine error state
    final errorMessage = combinedWealthAsync.hasError
        ? combinedWealthAsync.error.toString()
        : balancesAsync.hasError
            ? balancesAsync.error.toString()
            : charactersAsync.hasError
                ? charactersAsync.error.toString()
                : null;

    return DashboardCard(
      title: 'Total Wealth',
      icon: Icons.account_balance_wallet,
      glowColor: EveColors.evePrimary,
      isLoading: isLoading,
      errorMessage: errorMessage,
      onRetry: () {
        ref.invalidate(allCharacterBalancesProvider);
        ref.invalidate(allCharactersProvider);
      },
      child: combinedWealthAsync.when(
        data: (totalWealth) => balancesAsync.when(
          data: (balances) => charactersAsync.when(
            data: (characters) => _buildContent(
              context,
              totalWealth,
              balances,
              characters,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    double totalWealth,
    Map<int, double> balances,
    List<Character> characters,
  ) {
    // Filter characters to only those with balances
    final charactersWithBalances = characters
        .where((char) => balances.containsKey(char.characterId))
        .toList();

    // Sort by balance (highest first)
    charactersWithBalances.sort((a, b) {
      final balanceA = balances[a.characterId] ?? 0.0;
      final balanceB = balances[b.characterId] ?? 0.0;
      return balanceB.compareTo(balanceA);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Total wealth display
        Center(
          child: Text(
            formatIsk(totalWealth),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: EveColors.evePrimary,
                ),
          ),
        ),

        if (charactersWithBalances.isNotEmpty) ...[
          const SizedBox(height: 24),

          // Per-character breakdown
          ...charactersWithBalances.map((character) {
            final balance = balances[character.characterId] ?? 0.0;
            final percentage = totalWealth > 0 ? (balance / totalWealth) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CharacterWealthRow(
                character: character,
                balance: balance,
                percentage: percentage,
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// Single row showing a character's wealth contribution.
class _CharacterWealthRow extends StatelessWidget {
  const _CharacterWealthRow({
    required this.character,
    required this.balance,
    required this.percentage,
  });

  final Character character;
  final double balance;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Character avatar
        CharacterAvatar(
          portraitUrl: character.portraitUrl,
          size: CharacterAvatarSize.small,
        ),
        const SizedBox(width: 8),

        // Character name
        Expanded(
          flex: 2,
          child: Text(
            character.name,
            style: Theme.of(context).textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),

        // Visual progress bar
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: EveColors.darkSurfaceVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(
                EveColors.evePrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Amount and percentage
        SizedBox(
          width: 120,
          child: Text(
            '${formatIskCompact(balance)} (${(percentage * 100).toStringAsFixed(0)}%)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
