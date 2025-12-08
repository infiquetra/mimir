import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/theme/eve_spacing.dart';
import '../../../../../core/theme/eve_typography.dart';
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
            style: EveTypography.headline(
              color: EveColors.photonBlue,
            ),
          ),
        ),

        if (charactersWithBalances.isNotEmpty) ...[
          SizedBox(height: EveSpacing.lg),

          // Per-character breakdown
          ...charactersWithBalances.map((character) {
            final balance = balances[character.characterId] ?? 0.0;
            final percentage = totalWealth > 0 ? (balance / totalWealth) : 0.0;

            return Padding(
              padding: EdgeInsets.only(bottom: EveSpacing.md),
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
        SizedBox(width: EveSpacing.md),

        // Character name
        Expanded(
          flex: 2,
          child: Text(
            character.name,
            style: EveTypography.bodySmall(color: EveColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: EveSpacing.md),

        // Visual progress bar
        Expanded(
          flex: 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(EveSpacing.sm),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: EveColors.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                EveColors.photonBlue,
              ),
            ),
          ),
        ),
        SizedBox(width: EveSpacing.md),

        // Amount and percentage
        SizedBox(
          width: 110,
          child: Text(
            '${formatIskCompact(balance)} (${(percentage * 100).toStringAsFixed(0)}%)',
            style: EveTypography.dataSmall(
              color: EveColors.textSecondary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
