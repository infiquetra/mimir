import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../../characters/data/character_providers.dart';
import '../data/industry_providers.dart';
import 'widgets/blueprint_list_panel.dart';
import 'widgets/industry_jobs_panel.dart';
import 'widgets/invention_calculator_panel.dart';
import 'widgets/reaction_calculator_panel.dart';
import 'widgets/production_chain_visualizer.dart';

/// Main screen for Industry & Manufacturing feature.
class IndustryOverviewScreen extends ConsumerStatefulWidget {
  const IndustryOverviewScreen({super.key});

  @override
  ConsumerState<IndustryOverviewScreen> createState() =>
      _IndustryOverviewScreenState();
}

class _IndustryOverviewScreenState extends ConsumerState<IndustryOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    return ref.refresh(syncIndustryProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final activeCharacter = ref.watch(activeCharacterProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry & Manufacturing'),
        actions: [
          if (activeCharacter != null) RefreshAppBarAction(onRefresh: _refresh),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Industry Jobs', icon: Icon(Icons.factory)),
            Tab(text: 'Blueprints', icon: Icon(Icons.architecture)),
            Tab(text: 'Invention', icon: Icon(Icons.science)),
            Tab(text: 'Reactions', icon: Icon(Icons.transform)),
            Tab(text: 'Production Chains', icon: Icon(Icons.account_tree)),
          ],
        ),
      ),
      body: activeCharacter == null
          ? _buildNoCharacterState()
          : TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: IndustryJobsPanel(),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: BlueprintListPanel(),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: InventionCalculatorPanel(),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ReactionCalculatorPanel(),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: ProductionChainVisualizer(),
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
            'Please select a character to view industry data.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: EveColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
