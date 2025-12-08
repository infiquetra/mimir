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
    final balance = ref.watch(walletBalanceProvider);
    final plexCount = ref.watch(plexCountProvider);
    final lpCorporations = ref.watch(loyaltyPointsByCorporationProvider);

    // Handle loading state
    if (balance.isLoading || plexCount.isLoading || lpCorporations.isLoading) {
      return const SizedBox(
        height: 36,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Handle error state
    if (balance.hasError || plexCount.hasError || lpCorporations.hasError) {
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

    // Calculate total LP across all corporations
    double totalLP = 0.0;
    if (lpCorporations.hasValue && lpCorporations.value != null) {
      for (final corp in lpCorporations.value!) {
        totalLP += corp.loyaltyPoints.toDouble();
      }
    }

    // Build balances map
    final balances = {
      'ISK': balance.value ?? 0.0,
      'PLEX': plexCount.value?.toDouble() ?? 0.0,
      'LP': totalLP,
    };

    return BalanceChipRow(balances: balances);
  }
}
