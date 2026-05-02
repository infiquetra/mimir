import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/logger.dart';
import '../../../core/widgets/space_background.dart';
import '../../characters/data/character_providers.dart';
import 'widgets/skill_group_grid.dart';
import 'widgets/skill_list_panel.dart';
import 'widgets/skill_plans_panel.dart';
import 'widgets/skills_top_bar.dart';
import 'widgets/training_queue_sidebar.dart';

/// EVE Online-style skills screen with vertical character navigation.
///
/// Features:
/// - Left nav rail with character avatars (60px wide, Discord-style)
/// - Tabbed interface (Skill Plans | Skill Catalogue)
/// - Filter dropdown and search (top-right)
/// - Skill group grid (3 columns) with progress bars behind names
/// - Skill list (2 columns) with level squares
/// - Training queue sidebar (fixed 560px on right)
///
/// Layout:
/// ```
/// ┌──┬──────────────────────────────────────────┬────────────────────────┐
/// │🟢│ Plans | Catalogue | [Filter] [Search]    │ Queue (560px)          │
/// │──├──────────────────────────────────────────┤                        │
/// │👤│ Tab Content:                              │ [Queue Items]          │
/// │──│  - Skill Plans (existing)                │ ...                    │
/// │👤│  - Skill Catalogue:                       │                        │
/// │──│    ┌──────────────────────────────┐      │ [Queue Footer]         │
/// │+│    │ Skill Groups Grid (3 cols)   │      │ - Unalloc SP           │
/// │  │    ├──────────────────────────────┤      │ - Training Time        │
/// │  │    │ Skills List (2 cols)         │      │ - SP in Queue          │
/// │  │    └──────────────────────────────┘      │                        │
/// └──┴──────────────────────────────────────────┴────────────────────────┘
///  60px                                             560px
/// ```
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
    Log.d('SKILLS', 'SkillsScreen.initState() - creating TabController (2 tabs), starting on Skill Catalogue');
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
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

  /// Builds the main skills content with horizontal split layout.
  Widget _buildSkillsContent(BuildContext context) {
    Log.d('SKILLS', 'SkillsScreen._buildSkillsContent() - building EVE-style layout');

    return Row(
      children: [
        // Center panel: Top bar + Tab content
        Expanded(
          child: Column(
            children: [
              // Top bar with tabs, filter, search
              SkillsTopBar(tabController: _tabController),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 0: Skill Plans (existing panel)
                    const SkillPlansPanel(),

                    // Tab 1: Skill Catalogue (new EVE-style layout)
                    _buildSkillCatalogueTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Right sidebar: Training Queue (fixed 560px)
        const TrainingQueueSidebar(),
      ],
    );
  }

  /// Builds the Skill Catalogue tab with group grid and skill list.
  Widget _buildSkillCatalogueTab(BuildContext context) {
    Log.d('SKILLS', 'SkillsScreen._buildSkillCatalogueTab() - building catalogue');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          // Skill Groups Grid (3 columns, dynamic height)
          SkillGroupGrid(),

          SizedBox(height: 12),

          // Skills List Panel (2 columns)
          SkillListPanel(),
        ],
      ),
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
