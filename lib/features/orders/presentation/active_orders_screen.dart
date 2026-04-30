import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';

/// Market order view data.
///
/// This is a minimal view model for displaying market orders.
/// It is not persisted to the database — live ESI integration
/// for orders is a future follow-up (see PR description).
class Order {
  final int orderId;
  final int typeId;
  final String typeName;
  final int quantity;
  final double price; // ISK per unit
  final bool isBuyOrder;
  final String location;
  final Duration timeRemaining;
  final DateTime issuedDate;

  const Order({
    required this.orderId,
    required this.typeId,
    required this.typeName,
    required this.quantity,
    required this.price,
    required this.isBuyOrder,
    required this.location,
    required this.timeRemaining,
    required this.issuedDate,
  });
}

/// Placeholder orders data for UI development and testing.
///
/// In a future iteration, this will be replaced by live ESI data
/// fetched via the market orders endpoint.
///
/// Until then, sample orders help verify the screen renders correctly
/// and demonstrate the intended layout.
final _sampleOrders = [
  Order(
    orderId: 1,
    typeId: 34,
    typeName: 'Tritanium',
    quantity: 100000,
    price: 5.50,
    isBuyOrder: true,
    location: 'Jita IV - Moon 4',
    timeRemaining: const Duration(days: 2, hours: 4),
    issuedDate: DateTime.now().subtract(const Duration(days: 2)),
  ),
  Order(
    orderId: 2,
    typeId: 35,
    typeName: 'Pyerite',
    quantity: 50000,
    price: 2.30,
    isBuyOrder: false,
    location: 'Jita IV - Moon 4',
    timeRemaining: const Duration(days: 0, hours: 12, minutes: 30),
    issuedDate: DateTime.now().subtract(const Duration(days: 7)),
  ),
  Order(
    orderId: 3,
    typeId: 36,
    typeName: 'Mexallon',
    quantity: 25000,
    price: 12.75,
    isBuyOrder: true,
    location: 'Amarr VIII',
    timeRemaining: Duration.zero,
    issuedDate: DateTime.now().subtract(const Duration(days: 14)),
  ),
  Order(
    orderId: 4,
    typeId: 38,
    typeName: 'Nocxium',
    quantity: 10000,
    price: 410.00,
    isBuyOrder: false,
    location: 'Dodixie IX - Moon 20',
    timeRemaining: const Duration(days: 5, hours: 18),
    issuedDate: DateTime.now().subtract(const Duration(days: 9)),
  ),
  Order(
    orderId: 5,
    typeId: 40,
    typeName: 'Zydrine',
    quantity: 5000,
    price: 1850.00,
    isBuyOrder: true,
    location: 'Rens VI - Moon 8',
    timeRemaining: const Duration(days: 1, hours: 6),
    issuedDate: DateTime.now().subtract(const Duration(days: 13)),
  ),
];

/// Provider that returns the list of active orders.
///
/// Currently returns placeholder data. A future PR will replace
/// this with live ESI market orders data.
final activeOrdersProvider = FutureProvider<List<Order>>((ref) async {
  Log.d('ORDERS', 'activeOrdersProvider - fetching orders');
  // TODO(mimir-447): Replace with live ESI call:
  //   await ref.read(esiClientProvider).getMarketOrders(characterId);
  await Future.delayed(const Duration(milliseconds: 300));
  return _sampleOrders;
});

/// Active orders screen showing current market orders.
///
/// Displays a table of buy and sell orders with:
/// - Item name and type
/// - Quantity and price
/// - Duration remaining
/// - Order type (buy/sell)
class ActiveOrdersScreen extends ConsumerStatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  ConsumerState<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends ConsumerState<ActiveOrdersScreen> {
  Future<void> _refresh(int characterId) async {
    Log.d('ORDERS', '_refresh($characterId)');
    ref.invalidate(activeOrdersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final activeCharacterAsync = ref.watch(activeCharacterProvider);

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacterAsync.when(
          data: (character) {
            if (character == null) {
              return _buildNoCharacterState(context);
            }
            return _buildOrdersContent(context, character.characterId);
          },
          loading: () => _buildLoadingState(context),
          error: (error, stack) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a character to view market orders.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Orders',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersContent(BuildContext context, int characterId) {
    final ordersAsync = ref.watch(activeOrdersProvider);

    return Column(
      children: [
        // App bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                'Active Orders',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => _refresh(characterId),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildOrdersTable(context, orders);
            },
            loading: () => _buildLoadingState(context),
            error: (error, stack) => _buildErrorState(context, error),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Orders',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your market orders will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(BuildContext context, List<Order> orders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const SizedBox(width: 40, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 80, child: Text('Order', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 100, child: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                const SizedBox(width: 100, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                const SizedBox(width: 150, child: Text('Location', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(child: Text('Time Left', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Order rows
          ...orders.map((order) => _OrderRow(order: order)),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;

  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Icon(
              order.isBuyOrder ? Icons.arrow_downward : Icons.arrow_upward,
              color: order.isBuyOrder ? Colors.green : Colors.orange,
              size: 18,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              order.typeName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _formatQuantity(order.quantity),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              _formatPrice(order.price),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: order.isBuyOrder ? Colors.green.shade300 : Colors.orange.shade300,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              order.location,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: Text(
              _formatOrderDuration(order.timeRemaining),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _timeRemainingColor(order.timeRemaining, colorScheme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(int quantity) {
    if (quantity >= 1000000) {
      return '${(quantity / 1000000).toStringAsFixed(1)}M';
    } else if (quantity >= 1000) {
      return '${(quantity / 1000).toStringAsFixed(0)}K';
    }
    return quantity.toString();
  }

  String _formatPrice(double price) {
    return '${price.toStringAsFixed(2)} ISK';
  }

  String _formatOrderDuration(Duration duration) {
    if (duration == Duration.zero) {
      return 'Expired';
    }
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');

    return parts.join(' ');
  }

  Color _timeRemainingColor(Duration duration, ColorScheme colorScheme) {
    if (duration == Duration.zero) {
      return colorScheme.error;
    }
    if (duration.inHours < 24) {
      return Colors.orange;
    }
    return colorScheme.onSurface;
  }
}
