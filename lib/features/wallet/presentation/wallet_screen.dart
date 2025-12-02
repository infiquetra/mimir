import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/widgets/space_background.dart';
import '../../../core/widgets/streamlined_tab_bar.dart';
import '../../characters/data/character_providers.dart';
import 'widgets/balance_cards_row.dart';
import 'widgets/market_transactions_panel.dart';
import 'widgets/overview_panel.dart';
import 'widgets/transactions_panel.dart';

/// Enhanced wallet screen with EVE Online-style interface.
///
/// Features:
/// - Balance cards row (ISK, PLEX, LP Corporations, EverMarks)
/// - Tabbed interface (Overview, Transactions, Market Transactions)
/// - Advanced filtering and pagination
/// - 30-day income/expense summary
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    Log.d('WALLET', 'WalletScreen.initState() - creating TabController');
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      Log.d('WALLET', 'TabController - switched to tab ${_tabController.index}');
    });
  }

  @override
  void dispose() {
    Log.d('WALLET', 'WalletScreen.dispose() - disposing TabController');
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Scaffold(
      body: SpaceBackground(
        starDensity: 0.3,
        nebulaOpacity: 0.06,
        child: activeCharacter == null
            ? _buildNoCharacterState(context)
            : _buildWalletContent(context, activeCharacter.characterId),
      ),
    );
  }

  /// Builds the main wallet content with tabs.
  Widget _buildWalletContent(BuildContext context, int characterId) {
    return Column(
      children: [
        // Balance Cards Row (compact horizontal layout)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: const BalanceCardsRow(),
        ),

        const SizedBox(height: 8),

        // Tab Bar
        StreamlinedTabBar(
          controller: _tabController,
          tabs: const ['Overview', 'Transactions', 'Market'],
        ),

        // Tab Views - takes remaining space
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              OverviewPanel(),
              TransactionsPanel(),
              MarketTransactionsPanel(),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the no character selected state.
  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: Colors.white.withAlpha(128),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Character Selected',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to view your wallet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
