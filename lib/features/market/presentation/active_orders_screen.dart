import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../../core/widgets/space_background.dart';
import '../../../core/widgets/streamlined_tab_bar.dart';
import '../../characters/data/character_providers.dart';
import '../data/models/character_order.dart';
import '../data/repositories/orders_repository.dart';

/// Screen displaying a character's active market orders, split into buy and sell tabs.
class ActiveOrdersScreen extends ConsumerStatefulWidget {
  const ActiveOrdersScreen({super.key});

  @override
  ConsumerState<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends ConsumerState<ActiveOrdersScreen>
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

  Future<void> _refresh(int characterId) async {
    ref.invalidate(characterOrdersProvider(characterId));
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
          error: (error, _) => _buildErrorState(context, error),
        ),
      ),
    );
  }

  Widget _buildOrdersContent(BuildContext context, int characterId) {
    final ordersAsync = ref.watch(characterOrdersProvider(characterId));

    return Column(
      children: [
        // AppBar equivalent
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Active Orders',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              RefreshAppBarAction(
                onRefresh: () => _refresh(characterId),
                tooltip: 'Refresh active orders',
              ),
            ],
          ),
        ),

        // Tab bar
        StreamlinedTabBar(
          controller: _tabController,
          tabs: const ['Buy Orders', 'Sell Orders'],
        ),

        // Content
        Expanded(
          child: ordersAsync.when(
            data: (orders) => _OrdersContent(
              orders: orders,
              tabController: _tabController,
            ),
            loading: () => _buildLoadingState(context),
            error: (error, _) => _buildErrorState(context, error),
          ),
        ),
      ],
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return const EmptyState(
      icon: Icons.person_off_outlined,
      heading: 'No Character Selected',
      description: 'Add a character to view your market orders.',
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Text(
        'Loading active orders',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withAlpha(204),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load active orders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// The tabbed order lists.
class _OrdersContent extends StatelessWidget {
  const _OrdersContent({
    required this.orders,
    required this.tabController,
  });

  final List<CharacterOrder> orders;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final buyOrders = orders
        .where((o) => o.isBuyOrder && o.state == OrderState.active)
        .toList();
    final sellOrders = orders
        .where((o) => !o.isBuyOrder && o.state == OrderState.active)
        .toList();

    return TabBarView(
      controller: tabController,
      children: [
        _OrderList(orders: buyOrders, emptyMessage: 'No buy orders'),
        _OrderList(orders: sellOrders, emptyMessage: 'No sell orders'),
      ],
    );
  }
}

/// A scrollable list of order cards, or an empty state.
class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyMessage,
  });

  final List<CharacterOrder> orders;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _OrderCard(order: orders[index]);
      },
    );
  }
}

/// A card displaying a single market order's key details.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final CharacterOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1a1a2e),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: type name + price
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.typeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatIsk(order.price),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: order.isBuyOrder ? Colors.green : Colors.cyan,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Location
            Text(
              order.locationName,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),

            const SizedBox(height: 12),

            // Volume + fill progress
            Row(
              children: [
                Text(
                  '${order.volumeRemain} / ${order.volumeTotal}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label:
                        'Order fill progress for ${order.typeName}',
                    value:
                        '${(order.fillPercent * 100).round()} percent filled',
                    child: LinearProgressIndicator(
                      value: order.fillPercent,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        order.isBuyOrder ? Colors.green : Colors.cyan,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Footer: remaining value + expiry
            Row(
              children: [
                Text(
                  _formatIsk(order.remainingValue),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const Spacer(),
                Text(
                  'Expires: ${_formatExpiry(order.expires)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatIsk(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return '${formatter.format(amount)} ISK';
  }

  String _formatExpiry(DateTime expires) {
    final now = DateTime.now();
    if (now.isAfter(expires)) {
      return 'expired';
    }
    final remaining = expires.difference(now);
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');

    return parts.join(' ');
  }
}
