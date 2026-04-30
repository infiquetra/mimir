import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/theme/eve_colors.dart';
import 'package:mimir/core/utils/formatters.dart';
import 'package:mimir/core/widgets/space_background.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';

/// Screen that displays active market orders for the selected character.
class ActiveOrdersScreen extends ConsumerWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SpaceBackground(
        child: activeCharacterAsync.when(
          data: (character) {
            if (character == null) {
              return _buildEmptyState(
                context,
                Icons.person_off_outlined,
                'No Character Selected',
                'Add a character to view active market orders.',
              );
            }
            return const _OrdersBody();
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildErrorState(
            context,
            'Failed to Load Character',
            error.toString(),
            null,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String heading,
    String description,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: EveColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EveColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EveColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String heading,
    String message,
    VoidCallback? onRetry,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: EveColors.error),
          const SizedBox(height: 16),
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EveColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EveColors.textSecondary,
                  ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _OrdersBody extends ConsumerWidget {
  const _OrdersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(activeOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return _buildEmptyState(
            context,
            Icons.receipt_long_outlined,
            'No Active Orders',
            'This character has no active market orders.',
          );
        }
        return _OrdersList(orders: orders, ref: ref);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(
        context,
        'Failed to Load Orders',
        error.toString(),
        () => ref.invalidate(activeOrdersProvider),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String heading,
    String description,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: EveColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EveColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EveColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String heading,
    String message,
    VoidCallback? onRetry,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: EveColors.error),
          const SizedBox(height: 16),
          Text(
            heading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: EveColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: EveColors.textSecondary,
                  ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({required this.orders, required this.ref});

  final List<CharacterOrder> orders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeOrdersProvider);
        await ref.read(activeOrdersProvider.future);
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: kToolbarHeight + 32,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        itemCount: orders.length,
        itemBuilder: (context, index) => _OrderCard(order: orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CharacterOrder order;

  @override
  Widget build(BuildContext context) {
    final formattedPrice = formatIsk(order.price);
    final remainingDuration = order.expires.difference(DateTime.now());
    final remainingText = remainingDuration.isNegative
        ? 'Expired'
        : '${remainingDuration.inDays}d ${remainingDuration.inHours.remainder(24)}h remaining';

    final semanticsLabel =
        '${order.isBuyOrder ? "Buy" : "Sell"} order for ${order.typeName} at ${order.locationName}. '
        'Price: $formattedPrice. '
        'Volume: ${order.volumeRemain} / ${order.volumeTotal}. '
        '$remainingText.';

    return Semantics(
      label: semanticsLabel,
      child: Card(
        color: EveColors.surfaceDefault,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: EveColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _OrderSideBadge(isBuyOrder: order.isBuyOrder),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.typeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: EveColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.locationName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: EveColors.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              _OrderSummaryLine(label: 'Price', value: formattedPrice),
              _OrderSummaryLine(
                label: 'Volume',
                value: '${order.volumeRemain} / ${order.volumeTotal}',
              ),
              _OrderSummaryLine(label: 'Remaining', value: remainingText),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: order.fillPercent.clamp(0.0, 1.0),
                semanticsLabel: 'Order fill progress for ${order.typeName}',
                semanticsValue: (order.fillPercent * 100)
                    .clamp(0.0, 100.0)
                    .toStringAsFixed(1),
                backgroundColor: EveColors.borderSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(
                  order.isBuyOrder
                      ? EveColors.iskNegative
                      : EveColors.iskPositive,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(order.fillPercent * 100).clamp(0.0, 100.0).toStringAsFixed(1)}% filled',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: EveColors.textTertiary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderSideBadge extends StatelessWidget {
  const _OrderSideBadge({required this.isBuyOrder});

  final bool isBuyOrder;

  @override
  Widget build(BuildContext context) {
    final color = isBuyOrder ? EveColors.iskNegative : EveColors.iskPositive;
    final label = isBuyOrder ? 'Buy' : 'Sell';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _OrderSummaryLine extends StatelessWidget {
  const _OrderSummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: EveColors.textTertiary,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EveColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }
}
