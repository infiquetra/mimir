import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';

/// List item widget for displaying a wallet journal transaction.
///
/// Shows date, type, amount, balance, and description in a table-like format.
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
    final amountColor = isPositive
        ? const Color(0xFF4CAF50) // Green for income
        : const Color(0xFFF44336); // Red for expenses

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withAlpha(13),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Date and Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(entry.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(entry.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),

              // Type
              Expanded(
                flex: 2,
                child: Text(
                  _formatRefType(entry.refType),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withAlpha(179),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Amount
              Expanded(
                flex: 2,
                child: Text(
                  '${isPositive ? '+' : ''}${formatIsk(entry.amount)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Row 2: Balance and Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Text(
                      'Balance: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(128),
                      ),
                    ),
                    Text(
                      formatIsk(entry.balance),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withAlpha(179),
                      ),
                    ),
                  ],
                ),
              ),

              // Description
              Expanded(
                flex: 4,
                child: entry.description != null && entry.description!.isNotEmpty
                    ? Text(
                        entry.description!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withAlpha(153),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Formats date as "Jan 15, 2025".
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  /// Formats time as "14:30".
  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// Formats ref_type as human-readable (e.g., "market_transaction" → "Market Transaction").
  String _formatRefType(String refType) {
    return refType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
