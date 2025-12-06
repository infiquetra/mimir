import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../wallet/data/wallet_providers.dart';

/// List item widget for displaying a market transaction.
///
/// Shows date, item icon, item name, quantity, price, total, and location in a table-like format.
class MarketTransactionItem extends ConsumerWidget {
  /// The wallet transaction to display.
  final WalletTransaction transaction;

  const MarketTransactionItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = transaction.isBuy;
    final typeColor = isBuy
        ? const Color(0xFF4CAF50) // Green for buy
        : const Color(0xFFF44336); // Red for sell
    final total = transaction.unitPrice * transaction.quantity;

    // Watch providers for item name and location name
    final itemNameAsync = ref.watch(itemNameProvider(transaction.typeId));
    final locationNameAsync = ref.watch(locationNameProvider(transaction.locationId));

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
          // Row 1: Date, Type indicator, and Item
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
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(transaction.date),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              ),

              // Buy/Sell indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: typeColor.withAlpha(77),
                    width: 1,
                  ),
                ),
                child: Text(
                  isBuy ? 'BUY' : 'SELL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Item icon and name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Item icon
                    EveTypeIcon(
                      typeId: transaction.typeId,
                      size: 32,
                      borderRadius: 4,
                    ),
                    const SizedBox(width: 8),
                    // Item name
                    Expanded(
                      child: itemNameAsync.when(
                        data: (itemName) => Text(
                          itemName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(179),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        loading: () => Container(
                          height: 13,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        error: (_, __) => Text(
                          'Item #${transaction.typeId}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(179),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Quantity, Unit Price, and Total
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: _buildInfoRow('Qty', transaction.quantity.toString()),
              ),

              // Unit Price
              Expanded(
                flex: 3,
                child: _buildInfoRow('Price', formatIsk(transaction.unitPrice)),
              ),

              // Total Value
              Expanded(
                flex: 3,
                child: _buildInfoRow('Total', formatIsk(total)),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Row 3: Location
          locationNameAsync.when(
            data: (locationName) => _buildInfoRow('Location', locationName),
            loading: () => _buildInfoRow('Location', 'Loading...'),
            error: (_, __) => _buildInfoRow('Location', 'Location ${transaction.locationId}'),
          ),
        ],
      ),
    );
  }

  /// Builds an info row with label and value.
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withAlpha(128),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withAlpha(179),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
}
