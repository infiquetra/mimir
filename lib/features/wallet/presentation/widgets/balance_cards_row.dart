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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use Wrap for responsive layout (2 cards per row on narrow screens)
        final isNarrow = constraints.maxWidth < 600;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // ISK Balance Card
            _buildCardContainer(
              isNarrow: isNarrow,
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

            // PLEX Card
            _buildCardContainer(
              isNarrow: isNarrow,
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

            // LP Corporations Card
            _buildCardContainer(
              isNarrow: isNarrow,
              child: BalanceCard(
                label: 'LP Corporations',
                value: lpCorporations.when(
                  data: (corps) => corps.isEmpty
                      ? '0'
                      : '${corps.length} ${corps.length == 1 ? 'Corporation' : 'Corporations'}',
                  loading: () => '...',
                  error: (_, __) => 'Error',
                ),
                icon: Icons.business,
                accentColor: EveColors.evePrimary,
                valueColor: Colors.white,
                isLoading: lpCorporations.isLoading,
              ),
            ),

            // EverMarks Card (Placeholder - no API)
            _buildCardContainer(
              isNarrow: isNarrow,
              child: const BalanceCard(
                label: 'EverMarks',
                value: 'N/A',
                icon: Icons.star_border,
                accentColor: Color(0xFF9370DB), // Purple
                valueColor: Colors.white70,
                trailing: Tooltip(
                  message: 'EverMarks data not available from ESI API',
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a card container with responsive sizing.
  Widget _buildCardContainer({
    required bool isNarrow,
    required Widget child,
  }) {
    // On narrow screens (mobile), use 2 cards per row
    // On wide screens (desktop), use 4 cards per row
    final width = isNarrow
        ? (600 - 12 - 24) / 2 // 2 cards with spacing and padding
        : null; // Let Wrap handle it

    return SizedBox(
      width: width,
      child: child,
    );
  }
}
