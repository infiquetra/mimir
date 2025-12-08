import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_spacing.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/utils/formatters.dart';

/// Compact transaction row for wallet journal (28px height).
///
/// Displays date, type, amount, and balance in a single table-like row.
class TransactionListItem extends StatelessWidget {
  /// The wallet journal entry to display.
  final WalletJournalEntry entry;

  const TransactionListItem({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.amount >= 0;
    final amountColor = isPositive ? EveColors.iskPositive : EveColors.iskNegative;

    return Container(
      height: EveSpacing.rowHeight,
      padding: EdgeInsets.symmetric(
        horizontal: EveSpacing.lg,
        vertical: EveSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: EveColors.divider,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Date column (flex 2)
          Expanded(
            flex: 2,
            child: Text(
              _formatCompactDate(entry.date),
              style: EveTypography.bodySmall(color: EveColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: EveSpacing.md),

          // Type column (flex 3)
          Expanded(
            flex: 3,
            child: Text(
              _formatRefType(entry.refType),
              style: EveTypography.bodySmall(color: EveColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: EveSpacing.md),

          // Amount column (flex 2)
          Expanded(
            flex: 2,
            child: Text(
              '${isPositive ? '+' : ''}${_formatCompactIsk(entry.amount)}',
              style: EveTypography.dataSmall(color: amountColor).copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: EveSpacing.md),

          // Balance column (flex 2)
          Expanded(
            flex: 2,
            child: Text(
              _formatCompactIsk(entry.balance),
              style: EveTypography.dataSmall(color: EveColors.textSecondary),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Formats date as "Dec 08" (compact).
  String _formatCompactDate(DateTime date) {
    return DateFormat('MMM dd').format(date);
  }

  /// Formats ISK with compact notation (1.5B, 50M, etc).
  String _formatCompactIsk(double amount) {
    final abs = amount.abs();
    if (abs >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B';
    } else if (abs >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  /// Formats ref_type as human-readable (e.g., "market_transaction" → "Market Transaction").
  String _formatRefType(String refType) {
    return refType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
