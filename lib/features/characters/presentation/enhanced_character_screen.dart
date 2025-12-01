import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../data/character_providers.dart';
import 'character_selector.dart';
import 'tabs/overview_tab.dart';

/// Enhanced character screen with tabbed interface.
///
/// Tabs:
/// - Overview: Character vitals, active clone, top standings
/// - Character: Detailed character info with sub-tabs
/// - Interactions: Contacts, standings, mail
///
/// Shows character selector in AppBar on mobile.
/// Desktop users see persistent sidebar (handled by app layout).
class EnhancedCharacterScreen extends ConsumerStatefulWidget {
  const EnhancedCharacterScreen({super.key});

  @override
  ConsumerState<EnhancedCharacterScreen> createState() =>
      _EnhancedCharacterScreenState();
}

class _EnhancedCharacterScreenState
    extends ConsumerState<EnhancedCharacterScreen>
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

  @override
  Widget build(BuildContext context) {
    final activeCharacter = ref.watch(activeCharacterProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Scaffold(
      backgroundColor: EveColors.darkBackground,
      appBar: AppBar(
        backgroundColor: EveColors.darkSurface,
        title: const Text('Character'),
        actions: [
          // Refresh button
          if (activeCharacter.hasValue && activeCharacter.value != null)
            RefreshAppBarAction(
              onRefresh: () => _refresh(ref, activeCharacter.value!.characterId),
            ),
          // Character selector (mobile only)
          if (isMobile) const CharacterSelector(),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: EveColors.evePrimary,
          labelColor: EveColors.evePrimary,
          unselectedLabelColor: Colors.white.withAlpha(179),
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_outlined),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.person_outlined),
              text: 'Character',
            ),
            Tab(
              icon: Icon(Icons.people_outlined),
              text: 'Interactions',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const OverviewTab(),
          _buildPlaceholderTab(
            context,
            'Character',
            Icons.person_outlined,
            'Detailed character information',
          ),
          _buildPlaceholderTab(
            context,
            'Interactions',
            Icons.people_outlined,
            'Contacts, standings, and mail',
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, int characterId) async {
    // Refresh character status data
    // This will be expanded in later phases
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Widget _buildPlaceholderTab(
    BuildContext context,
    String title,
    IconData icon,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: EveColors.evePrimary.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: EveColors.evePrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Coming in Phase ${title == "Character" ? "6" : "7"}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
