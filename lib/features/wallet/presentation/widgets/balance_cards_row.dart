import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/balance_chip.dart';
import '../../data/wallet_providers.dart';

/// Balance chips row for wallet overview.
///
/// Displays ISK, PLEX, and LP in a compact horizontal chip layout.
/// Height: ~36px (was ~100px with cards).
class BalanceCardsRow extends ConsumerWidget {
  const BalanceCardsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final plexAsync = ref.watch(plexCountProvider);
    final lpAsync = ref.watch(loyaltyPointsByCorporationProvider);

    return balanceAsync.when(
      data: (balance) => plexAsync.when(
        data: (plex) => lpAsync.when(
          data: (lps) {
            final totalLP = lps.fold<double>(0.0, (sum, corp) => sum + corp.loyaltyPoints);
            return BalanceChipRow(
              balances: {
                'ISK': balance ?? 0.0,
                'PLEX': plex.toDouble(),
                'LP': totalLP,
              },
            );
          },
          loading: _buildLoading,
          error: (_, __) => _buildError(),
        ),
        loading: _buildLoading,
        error: (_, __) => _buildError(),
      ),
      loading: _buildLoading,
      error: (_, __) => _buildError(),
    );
  }

  Widget _buildLoading() {
    return const SizedBox(
      height: 36,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 36,
      child: Center(
        child: Text(
          'Failed to load balances',
          style: TextStyle(color: Colors.red.shade300),
        ),
      ),
    );
  }
}
