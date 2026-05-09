import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
import '../../../../core/database/app_database.dart';
import '../../data/market_providers.dart';

/// Panel displaying the character's active market orders.
class ActiveOrdersPanel extends ConsumerWidget {
  const ActiveOrdersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeCharacterOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return const EmptyState(
            icon: Icons.storefront,
            heading: 'No Active Orders',
            description: 'You do not have any active market orders.',
          );
        }

        return ListView.builder(
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _OrderListItem(order: order);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => EmptyState(
        icon: Icons.error_outline,
        heading: 'Failed to Load Orders',
        description: err.toString(),
        action: ElevatedButton(
          onPressed: () => ref.refresh(activeCharacterOrdersProvider),
          child: const Text('Retry'),
        ),
      ),
    );
  }
}

class _OrderListItem extends ConsumerWidget {
  final MarketOrder order;

  const _OrderListItem({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final orderTypeColor = order.isBuyOrder ? Colors.blue.shade300 : Colors.orange.shade300;
    final orderTypeLabel = order.isBuyOrder ? 'BUY' : 'SELL';

    final filledVolume = order.volumeTotal - order.volumeRemain;
    final progress = (order.volumeTotal > 0) ? filledVolume / order.volumeTotal : 0.0;
    final expires = order.issued.add(Duration(days: order.duration));
    final isExpired = now.isAfter(expires);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: EveCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: orderTypeColor.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.all(2),
                child: EveTypeIcon(
                  typeId: order.typeId,
                  size: 48,
                ),
              ),
              const SizedBox(width: 16),
              
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Expanded(
                          // In MVP, we would use itemNameProvider to resolve typeId dynamically.
                          child: Text(
                            'Item #${order.typeId}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: orderTypeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: orderTypeColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            orderTypeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(color: orderTypeColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Stats row
                    Row(
                      children: [
                        Text(
                          formatIsk(order.price),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: EveColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$filledVolume / ${order.volumeTotal}',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        if (isExpired)
                          Text(
                            'Expired',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: EveColors.error,
                            ),
                          )
                        else
                          Text(
                            formatDuration(expires.difference(now)),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade200,
                            ),
                          ),
                      ],
                    ),
                    
                    // Progress Bar
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: EveColors.backgroundDeep.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(orderTypeColor),
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
