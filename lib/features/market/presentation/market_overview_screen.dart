import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../characters/data/character_providers.dart';
import '../data/market_providers.dart';
import 'widgets/active_orders_panel.dart';
import 'widgets/price_checker_panel.dart';

/// Main screen for the Market Tools feature.
class MarketOverviewScreen extends ConsumerStatefulWidget {
  const MarketOverviewScreen({super.key});

  @override
  ConsumerState<MarketOverviewScreen> createState() => _MarketOverviewScreenState();
}

class _MarketOverviewScreenState extends ConsumerState<MarketOverviewScreen> with SingleTickerProviderStateMixin {
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

  Future<void> _refresh() async {
    return ref.refresh(syncMarketProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final activeCharacterAsync = ref.watch(activeCharacterProvider);
    final activeCharacter = activeCharacterAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Market Tools'),
        actions: [
          if (activeCharacter != null)
            RefreshAppBarAction(onRefresh: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active Orders', icon: Icon(Icons.storefront)),
            Tab(text: 'Price Checker', icon: Icon(Icons.price_check)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          activeCharacterAsync.isLoading
              ? const Center(child: CircularProgressIndicator())
              : activeCharacter == null
                  ? _buildNoCharacterState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: ActiveOrdersPanel(),
                  ),
                ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: PriceCheckerPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCharacterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined, size: 64, color: EveColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a character to view active orders.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: EveColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
