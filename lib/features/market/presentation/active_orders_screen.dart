import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimir/core/utils/formatters.dart';
import 'package:mimir/core/widgets/empty_state.dart';
import 'package:mimir/core/widgets/streamlined_tab_bar.dart';
import 'package:mimir/features/characters/data/character_providers.dart';
import 'package:mimir/features/market/data/models/character_order.dart';
import 'package:mimir/features/market/data/repositories/orders_repository.dart';

/// Screen displaying a character's active market orders.
///
/// When [characterId] is provided directly, orders for that character are
/// loaded immediately. When [characterId] is null (the default), the
/// screen watches [activeCharacterProvider] to determine which character
/// to load orders for.
class ActiveOrdersScreen extends ConsumerWidget {
  /// Optional character ID. When null, the active character is used.
  final int? characterId;

  const ActiveOrdersScreen({super.key, this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (characterId != null) {
      return _ActiveOrdersContent(characterId: characterId!);
    }

    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return activeCharacterAsync.when(
      data: (character) {
        if (character == null) {
          return const EmptyState(
            icon: Icons.person_off_outlined,
            heading: 'No Character Selected',
            description:
                'Add or select a character to view active market orders.',
          );
        }
        return _ActiveOrdersContent(characterId: character.characterId);
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        heading: 'Failed to Load Character',
        description: error.toString(),
      ),
    );
  }
}

/// Content widget that loads and displays orders for a specific character.
class _ActiveOrdersContent extends ConsumerStatefulWidget {
  final int characterId;

  const _ActiveOrdersContent({required this.characterId});

  @override
  ConsumerState<_ActiveOrdersContent> createState() =>
      _ActiveOrdersContentState();
}

class _ActiveOrdersContentState extends ConsumerState<_ActiveOrdersContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync =
        ref.watch(characterOrdersProvider(widget.characterId));

    return Scaffold(
      body: ordersAsync.when(
        data: (orders) {
          final summary = OrderSummary.fromOrders(orders);
          final buyOrders =
              summary.activeBuyOrders;
          final sellOrders =
              summary.activeSellOrders;

          return Column(
            children: [
              // Summary strip
              _OrderSummaryStrip(summary: summary),
              const SizedBox(height: 8),
              // Tab bar
              StreamlinedTabBar(
                controller: _tabController,
                tabs: const ['Buy Orders', 'Sell Orders'],
              ),
              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderList(orders: buyOrders, emptyHeading: 'No Buy Orders'),
                    _OrderList(
                        orders: sellOrders, emptyHeading: 'No Sell Orders'),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          heading: 'Failed to Load Orders',
          description: error.toString(),
          action: TextButton.icon(
            onPressed: () =>
                ref.invalidate(characterOrdersProvider(widget.characterId)),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ),
    );
  }
}

/// A horizontal strip showing order summary statistics.
class _OrderSummaryStrip extends StatelessWidget {
  final OrderSummary summary;

  const _OrderSummaryStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryChip(
              label: 'Buy Orders',
              value: '${summary.buyCount}',
              value2: formatIskCompact(summary.totalBuyValue),
              color: colorScheme.tertiary,
              textTheme: textTheme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SummaryChip(
              label: 'Sell Orders',
              value: '${summary.sellCount}',
              value2: formatIskCompact(summary.totalSellValue),
              color: colorScheme.primary,
              textTheme: textTheme,
            ),
          ),
          if (summary.totalEscrow > 0) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryChip(
                label: 'Escrow',
                value: formatIskCompact(summary.totalEscrow),
                color: colorScheme.secondary,
                textTheme: textTheme,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small chip in the summary strip.
class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final String? value2;
  final Color color;
  final TextTheme textTheme;

  const _SummaryChip({
    required this.label,
    required this.value,
    this.value2,
    required this.color,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: color.withAlpha(204),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (value2 != null) ...[
            const SizedBox(height: 1),
            Text(
              value2!,
              style: textTheme.bodySmall?.copyWith(
                color: color.withAlpha(179),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A scrollable list of order cards.
class _OrderList extends StatelessWidget {
  final List<CharacterOrder> orders;
  final String emptyHeading;

  const _OrderList({required this.orders, required this.emptyHeading});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        heading: emptyHeading,
        description: 'No active orders in this category.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: orders.length,
      itemBuilder: (context, index) => _OrderCard(order: orders[index]),
    );
  }
}

/// A card displaying a single active market order.
class _OrderCard extends StatelessWidget {
  final CharacterOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final sideColor =
        order.isBuyOrder ? colorScheme.tertiary : colorScheme.primary;
    final sideLabel = order.isBuyOrder ? 'BUY' : 'SELL';
    final filledPercent = (order.fillPercent * 100).toStringAsFixed(0);
    final filledPercentText = '$filledPercent%';
    final remainingValueText = formatIskCompact(order.remainingValue);
    final expiryText = _formatExpiry(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Side badge + type name
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sideColor.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sideLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sideColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.typeName,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 2: Price + location
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatIskCompact(order.price),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: colorScheme.onSurface.withAlpha(153),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.locationName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withAlpha(179),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Row 3: Progress bar with semantics
            Semantics(
              label:
                  'Order fill $filledPercentText; '
                  '${order.volumeRemain} of ${order.volumeTotal} units remaining; '
                  'remaining value $remainingValueText',
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${order.volumeRemain}/${order.volumeTotal}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withAlpha(204),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              filledPercentText,
                              style: textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: sideColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: order.fillPercent,
                            minHeight: 4,
                            backgroundColor:
                                colorScheme.onSurface.withAlpha(26),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(sideColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Row 4: Remaining value + expiry
            Row(
              children: [
                Text(
                  remainingValueText,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: sideColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: colorScheme.onSurface.withAlpha(128),
                ),
                const SizedBox(width: 4),
                Text(
                  expiryText,
                  style: textTheme.bodySmall?.copyWith(
                    color: order.isExpired
                        ? colorScheme.error
                        : colorScheme.onSurface.withAlpha(179),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats the expiry date of an order for display.
String _formatExpiry(CharacterOrder order) {
  final remaining = order.expires.difference(DateTime.now());
  if (remaining.isNegative) return 'Expired';
  if (remaining.inDays > 0) return '${remaining.inDays}d';
  if (remaining.inHours > 0) return '${remaining.inHours}h';
  if (remaining.inMinutes > 0) return '${remaining.inMinutes}m';
  return '<1m';
}
