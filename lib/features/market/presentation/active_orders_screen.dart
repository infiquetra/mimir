import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/character_order.dart';
import '../data/repositories/orders_repository.dart';

// ---------------------------------------------------------------------------
// Riverpod provider – one-shot fetch per character ID
// ---------------------------------------------------------------------------

final _activeOrdersProvider =
    FutureProvider.family<List<CharacterOrder>, int>((ref, characterId) async {
  final repository = ref.watch(ordersRepositoryProvider);
  return repository.getCharacterOrders(characterId);
});

// ---------------------------------------------------------------------------
// Screen entry point
// ---------------------------------------------------------------------------

/// Displays active buy and sell market orders for a character.
///
/// [characterId] identifies the EVE character whose orders are shown.
/// A screen reader is supported via tooltips and semantic labels on
/// interactive controls.
class ActiveOrdersScreen extends ConsumerWidget {
  final int characterId;

  const ActiveOrdersScreen({super.key, required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh active orders',
            onPressed: () =>
                ref.invalidate(_activeOrdersProvider(characterId)),
          ),
        ],
      ),
      body: _SpaceBackground(
        child: _ActiveOrdersContent(characterId: characterId),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Content widget – watches the provider
// ---------------------------------------------------------------------------

class _ActiveOrdersContent extends ConsumerWidget {
  final int characterId;

  const _ActiveOrdersContent({required this.characterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_activeOrdersProvider(characterId));

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _EmptyState(
        icon: Icons.error_outline,
        heading: 'Failed to Load Orders',
        description: error.toString(),
        onRetry: () =>
            ref.invalidate(_activeOrdersProvider(characterId)),
      ),
      data: _buildData,
    );
  }

  Widget _buildData(List<CharacterOrder> orders) {
    if (orders.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_cart_outlined,
        heading: 'No Active Orders',
        description: 'No active market orders found for this character.',
      );
    }

    final buyOrders =
        orders.where((o) => o.isBuyOrder).toList();
    final sellOrders =
        orders.where((o) => !o.isBuyOrder).toList();

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
                  emptyLabel: 'No Buy Orders',
                ),
                _OrderList(
                  orders: sellOrders,
                  emptyLabel: 'No Sell Orders',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order list
// ---------------------------------------------------------------------------

class _OrderList extends StatelessWidget {
  final List<CharacterOrder> orders;
  final String emptyLabel;

  const _OrderList({required this.orders, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(
        icon: Icons.shopping_cart_outlined,
        heading: emptyLabel,
        description: 'No active market orders found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: orders.length,
      itemBuilder: (_, index) => _OrderCard(order: orders[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Order card
// ---------------------------------------------------------------------------

class _OrderCard extends StatelessWidget {
  final CharacterOrder order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filledPercent = (order.fillPercent * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: type name + price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.typeName,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatIsk(order.price),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: order.isBuyOrder ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Location
            Text(
              order.locationName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 8),

            // Volume info
            Text(
              '${order.volumeRemain} / ${order.volumeTotal} units remaining',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),

            // Progress bar with accessibility
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: '${order.typeName} order fill progress',
                    value: '$filledPercent% filled',
                    child: LinearProgressIndicator(value: order.fillPercent),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$filledPercent% filled'),
              ],
            ),
            const SizedBox(height: 4),

            // Expiry
            Text(
              _formatExpiry(order.expires),
              style: theme.textTheme.bodySmall?.copyWith(
                color: order.isExpired
                    ? Colors.redAccent
                    : theme.colorScheme.onSurface.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal private utilities substituting for core/ infrastructure
// ---------------------------------------------------------------------------

/// Formats an ISK amount: e.g. 1234567.0 → "1,234,567 ISK".
String _formatIsk(double value) {
  final integerPart = value.toInt();
  final str = integerPart.abs().toString();
  final reversed = str.split('').reversed.toList();
  final grouped = <String>[];
  for (var i = 0; i < reversed.length; i++) {
    if (i > 0 && i % 3 == 0) grouped.add(',');
    grouped.add(reversed[i]);
  }
  final formatted = grouped.reversed.join();
  final sign = integerPart < 0 ? '-' : '';
  return '$sign$formatted ISK';
}

/// Returns a human-readable expiry string.
String _formatExpiry(DateTime expires) {
  final now = DateTime.now();
  if (expires.isBefore(now)) return 'Expired';

  final remaining = expires.difference(now);
  if (remaining.inDays > 0) {
    return 'Expires in ${remaining.inDays}d';
  } else if (remaining.inHours > 0) {
    return 'Expires in ${remaining.inHours}h';
  } else {
    return 'Expires in ${remaining.inMinutes}m';
  }
}

// ---------------------------------------------------------------------------
// Minimal SpaceBackground / EmptyState (stand-ins for core/ widgets)
// ---------------------------------------------------------------------------

class _SpaceBackground extends StatelessWidget {
  final Widget child;
  const _SpaceBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0E14), Color(0xFF1A1F2E)],
        ),
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String heading;
  final String description;
  final VoidCallback? onRetry;

  const _EmptyState({
    required this.icon,
    required this.heading,
    required this.description,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurface.withAlpha(100)),
            const SizedBox(height: 16),
            Text(heading, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
