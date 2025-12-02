import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/wallet_providers.dart';
import 'balance_card.dart';

/// Balance cards row for wallet overview.
///
/// Displays ISK, PLEX, LP Corporations, and EverMarks in a responsive row.
class BalanceCardsRow extends ConsumerWidget {
  const BalanceCardsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(walletBalanceProvider);
    final plexCount = ref.watch(plexCountProvider);
    final lpCorporations = ref.watch(loyaltyPointsByCorporationProvider);

    return SizedBox(
      height: 56, // Fixed compact height for horizontal row
      child: Row(
        children: [
          // ISK Balance Card
          Expanded(
            child: BalanceCard(
              label: 'ISK',
              value: balance.when(
                data: (bal) => bal != null ? formatIsk(bal) : 'N/A',
                loading: () => '...',
                error: (_, __) => 'Error',
              ),
              icon: Icons.account_balance_wallet,
              accentColor: const Color(0xFF00CED1), // Teal (EVE ISK color)
              valueColor: const Color(0xFFFFD700), // Gold
              isLoading: balance.isLoading,
            ),
          ),
          const SizedBox(width: 8),

          // PLEX Card
          Expanded(
            child: BalanceCard(
              label: 'PLEX',
              value: plexCount.when(
                data: (count) => count.toString(),
                loading: () => '...',
                error: (_, __) => 'Error',
              ),
              icon: Icons.credit_card,
              accentColor: const Color(0xFFFF8C00), // Orange
              valueColor: Colors.white,
              isLoading: plexCount.isLoading,
            ),
          ),
          const SizedBox(width: 8),

          // LP Corporations Card
          Expanded(
            child: BalanceCard(
              label: 'LP Corporations',
              value: lpCorporations.when(
                data: (corps) => corps.isEmpty
                    ? '0'
                    : '${corps.length} ${corps.length == 1 ? 'Corp' : 'Corps'}',
                loading: () => '...',
                error: (_, __) => 'Error',
              ),
              icon: Icons.business,
              accentColor: EveColors.evePrimary,
              valueColor: Colors.white,
              isLoading: lpCorporations.isLoading,
            ),
          ),
          const SizedBox(width: 8),

          // EverMarks Card (Placeholder - no API)
          Expanded(
            child: BalanceCard(
              label: 'EverMarks',
              value: 'N/A',
              icon: Icons.star_border,
              accentColor: const Color(0xFF9370DB), // Purple
              valueColor: Colors.white70,
              trailing: const Tooltip(
                message: 'EverMarks data not available from ESI API',
                child: Icon(
                  Icons.info_outline,
                  size: 12,
                  color: Colors.white54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
