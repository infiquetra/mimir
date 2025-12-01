import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/eve_colors.dart';
import '../../../core/widgets/refresh_app_bar_action.dart';
import '../data/character_providers.dart';
import '../data/character_status_providers.dart';
import 'character_selector.dart';
import 'tabs/character_tab.dart';
import 'tabs/interactions_tab.dart';
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
        children: const [
          OverviewTab(),
          CharacterTab(),
          InteractionsTab(),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref, int characterId) async {
    // Refresh character info from ESI
    await ref.read(refreshCharacterProvider(characterId).future);

    // Invalidate all character status providers to force re-fetch from ESI
    ref.invalidate(characterClonesProvider(characterId));
    ref.invalidate(characterImplantsProvider(characterId));
    ref.invalidate(characterStandingsProvider(characterId));
    ref.invalidate(characterAttributesProvider(characterId));
    ref.invalidate(characterOnlineStatusProvider(characterId));

    // Wait for the status data to be fetched
    await Future.wait([
      ref.read(characterClonesProvider(characterId).future),
      ref.read(characterImplantsProvider(characterId).future),
      ref.read(characterStandingsProvider(characterId).future),
      ref.read(characterAttributesProvider(characterId).future),
      ref.read(characterOnlineStatusProvider(characterId).future),
    ]);
  }
}
