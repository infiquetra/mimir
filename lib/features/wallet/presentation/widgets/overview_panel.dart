import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../data/wallet_providers.dart';

/// Overview panel displaying 30-day wallet summary.
///
/// Shows income, expenses, and net change with color-coded indicators.
class OverviewPanel extends ConsumerWidget {
  const OverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(walletSummaryProvider);

    return summary.when(
      data: (data) {
        // Show empty state if no transactions
        if (data.income == 0 && data.expenses == 0) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            heading: 'No Transactions',
            description: 'No wallet activity in the last 30 days.',
          );
        }

        return EveCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                '30-Day Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withAlpha(230),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Income Row
              _buildSummaryRow(
                label: 'Income',
                value: formatIsk(data.income),
                color: const Color(0xFF4CAF50), // Green
                icon: Icons.arrow_upward,
              ),
              const SizedBox(height: 12),

              // Expenses Row
              _buildSummaryRow(
                label: 'Expenses',
                value: formatIsk(data.expenses),
                color: const Color(0xFFF44336), // Red
                icon: Icons.arrow_downward,
              ),
              const SizedBox(height: 16),

              // Divider
              Divider(
                color: Colors.white.withAlpha(26),
                height: 1,
              ),
              const SizedBox(height: 16),

              // Net Change Row
              _buildSummaryRow(
                label: 'Net Change',
                value: formatIsk(data.net),
                color: data.net >= 0
                    ? const Color(0xFF4CAF50) // Green for profit
                    : const Color(0xFFF44336), // Red for loss
                icon: data.net >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                isBold: true,
              ),
            ],
          ),
        );
      },
      loading: () => const EveCard(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => EveCard(
        padding: const EdgeInsets.all(16),
        child: EmptyState(
          icon: Icons.error_outline,
          heading: 'Failed to Load Summary',
          description: error.toString(),
          action: ElevatedButton(
            onPressed: () => ref.refresh(walletSummaryProvider),
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }

  /// Builds a summary row with icon, label, and value.
  Widget _buildSummaryRow({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isBold = false,
  }) {
    return Row(
      children: [
        // Color indicator icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: color.withAlpha(77),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),

        // Label
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.white.withAlpha(204),
              letterSpacing: 0.3,
            ),
          ),
        ),

        // Value
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 15,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
