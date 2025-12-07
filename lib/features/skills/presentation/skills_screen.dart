import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/widgets/space_background.dart';
import '../../../core/widgets/streamlined_tab_bar.dart';
import '../../characters/data/character_providers.dart';
import 'widgets/skill_catalogue_panel.dart';
import 'widgets/skill_header_card.dart';
import 'widgets/skill_plans_panel.dart';
import 'widgets/training_queue_panel.dart';

/// Enhanced skills screen with EVE Online-style interface.
///
/// Features:
/// - Skill header card showing total SP and unallocated SP
/// - Tabbed interface:
///   1. Training Queue - Current skill queue with progress
///   2. Skill Catalogue - All skills organized by groups
///   3. Skill Plans - Custom skill plans with progress tracking
class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    Log.d('SKILLS', 'SkillsScreen.initState() - creating TabController');
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      Log.d('SKILLS', 'TabController - switched to tab ${_tabController.index}');
    });
  }

  @override
  void dispose() {
    Log.d('SKILLS', 'SkillsScreen.dispose() - disposing TabController');
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS', 'SkillsScreen.build() - START');
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
            Log.d('SKILLS', 'SkillsScreen - building content for character ${character.characterId}');
            return _buildSkillsContent(context);
          },
          loading: () {
            Log.d('SKILLS', 'SkillsScreen - loading character');
            return _buildLoadingState(context);
          },
          error: (error, stack) {
            Log.e('SKILLS', 'SkillsScreen - error loading character', error, stack);
            return _buildErrorState(context, error);
          },
        ),
      ),
    );
  }

  /// Builds the main skills content with tabs.
  Widget _buildSkillsContent(BuildContext context) {
    return Column(
      children: [
        // Skill Header Card (Total SP + Unallocated SP)
        const SkillHeaderCard(),

        // Tab Bar
        StreamlinedTabBar(
          controller: _tabController,
          tabs: const ['Training Queue', 'Skill Catalogue', 'Skill Plans'],
        ),

        // Tab Views - takes remaining space
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              TrainingQueuePanel(),
              SkillCataloguePanel(),
              SkillPlansPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Character Selected',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a character to view your skills.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Character',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
