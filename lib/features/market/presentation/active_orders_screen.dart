import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/eve_type_icon.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import '../data/models/character_order.dart';
import '../data/repositories/orders_repository.dart';

/// Screen that displays active market orders for the selected character.
class ActiveOrdersScreen extends ConsumerWidget {
  const ActiveOrdersScreen({super.key});

  Future<void> _refresh(WidgetRef ref, int characterId) async {
    ref.invalidate(characterOrdersProvider(characterId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          activeCharacterAsync.when(
            data: (character) {
              if (character == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh active market orders',
                onPressed: () => _refresh(ref, character.characterId),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacterAsync.when(
          data: (character) {
            if (character == null) {
              return const EmptyState(
                icon: Icons.person_off_outlined,
                heading: 'No Character Selected',
                description: 'Select a character to view active market orders.',
              );
            }
            return _OrdersContent(characterId: character.characterId);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline,
            heading: 'Failed to Load Character',
            description: error.toString(),
          ),
        ),
      ),
    );
  }
}

class _OrdersContent extends ConsumerWidget {
  final int characterId;

  const _OrdersContent({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(characterOrdersProvider(characterId));

    return ordersAsync.when(
      data: (orders) {
        final buyOrders = orders.where((o) => o.isBuyOrder).toList();
        final sellOrders = orders.where((o) => !o.isBuyOrder).toList();

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Buy Orders'),
                  Tab(text: 'Sell Orders'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _OrderList(
                      orders: buyOrders,
                      emptyHeading: 'No buy orders',
                    ),
                    _OrderList(
                      orders: sellOrders,
                      emptyHeading: 'No sell orders',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        heading: 'Failed to Load Orders',
        description: error.toString(),
        action: TextButton.icon(
          onPressed: () => ref.invalidate(characterOrdersProvider(characterId)),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<CharacterOrder> orders;
  final String emptyHeading;

  const _OrderList({
    required this.orders,
    required this.emptyHeading,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_outlined,
        heading: emptyHeading,
        description: 'No active orders on this side.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _OrderCard(order: orders[index]),
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  final CharacterOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final percent = order.fillPercent.clamp(0.0, 1.0);
    final isExpired = order.isExpired;
    final color = order.isBuyOrder ? Colors.greenAccent : Colors.orangeAccent;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: EveTypeIcon(typeId: order.typeId, size: 40),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.typeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.locationName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Order status',
                  value: isExpired ? 'Expired' : 'Active',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? Colors.redAccent.withAlpha(51)
                          : color.withAlpha(51),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isExpired ? Colors.redAccent : color,
                      ),
                    ),
                    child: Text(
                      isExpired ? 'Expired' : 'Active',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isExpired ? Colors.redAccent : color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoChip(
                  label: 'Price',
                  value: formatIskCompact(order.price),
                ),
                _InfoChip(
                  label: 'Remaining',
                  value: formatIskCompact(order.remainingValue),
                ),
                _InfoChip(
                  label: 'Volume',
                  value: '${order.volumeRemain}/${order.volumeTotal}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              label: 'Order fill progress',
              value: '${(percent * 100).toStringAsFixed(1)}% filled',
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.white.withAlpha(38),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              label: 'Order expiry',
              value:
                  'Expires ${order.expires.toIso8601String().split('T').first}',
              child: Text(
                'Expires: ${order.expires.toIso8601String().split('T').first}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withAlpha(153),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(153)),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
