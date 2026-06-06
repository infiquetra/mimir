import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../characters/data/character_providers.dart';
import '../data/market_providers.dart';
import 'widgets/active_orders_panel.dart';
import 'widgets/market_browser_panel.dart';
import 'widgets/trade_calculator_panel.dart';

/// Main screen for the Market Tools feature.
class MarketOverviewScreen extends ConsumerStatefulWidget {
  const MarketOverviewScreen({super.key});

  @override
  ConsumerState<MarketOverviewScreen> createState() =>
      _MarketOverviewScreenState();
}

class _MarketOverviewScreenState extends ConsumerState<MarketOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          if (activeCharacter != null) RefreshAppBarAction(onRefresh: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Browser', icon: Icon(Icons.search, size: 18)),
            Tab(text: 'My Orders', icon: Icon(Icons.storefront, size: 18)),
            Tab(
              text: 'Calculator',
              icon: Icon(Icons.calculate_outlined, size: 18),
            ),
          ],
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorColor: const Color(0xFF4FC3F7),
          labelColor: const Color(0xFF4FC3F7),
          unselectedLabelColor: EveColors.textSecondary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Browser tab — works without a character (uses public ESI endpoints)
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: MarketBrowserPanel(),
          ),
          // My Orders tab — requires a character
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
          // Calculator tab — pure client-side, no character needed
          const TradeCalculatorPanel(),
        ],
      ),
    );
  }

  Widget _buildNoCharacterState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 64,
            color: EveColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a character to view active orders.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: EveColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
