import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/sde/sde_database.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../data/skill_catalogue_providers.dart';
import 'add_to_plan_dialog.dart';
import 'skill_catalogue_item.dart';
import 'skill_group_row.dart';

/// Panel displaying the skill catalogue organized by groups.
///
/// Shows:
/// - Search bar for filtering skills by name
/// - All skill groups with expand/collapse functionality
/// - Progress bars showing trained vs total skills per group
/// - Individual skills with level indicators when expanded
class SkillCataloguePanel extends ConsumerStatefulWidget {
  const SkillCataloguePanel({super.key});

  @override
  ConsumerState<SkillCataloguePanel> createState() =>
      _SkillCataloguePanelState();
}

class _SkillCataloguePanelState extends ConsumerState<SkillCataloguePanel> {
  // Track which groups are expanded
  final Set<int> _expandedGroups = {};

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleGroup(int groupId) {
    setState(() {
      if (_expandedGroups.contains(groupId)) {
        _expandedGroups.remove(groupId);
      } else {
        _expandedGroups.add(groupId);
      }
    });
  }

  Future<void> _showAddToPlanDialog(
    BuildContext context,
    SdeType skill,
    int trainedLevel,
  ) async {
    Log.d(
      'SKILLS.CATALOGUE',
      '_showAddToPlanDialog - skill: ${skill.typeName}, trained: $trainedLevel',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddToPlanDialog(
        skill: skill,
        trainedLevel: trainedLevel,
      ),
    );

    if (result == true && mounted) {
      Log.i('SKILLS.CATALOGUE', '_showAddToPlanDialog - skill added successfully');
      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${skill.typeName} added to plan'),
          backgroundColor: EveColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS.CATALOGUE', 'SkillCataloguePanel.build - START');

    return Column(
      children: [
        // Search bar
        _buildSearchBar(context),

        const SizedBox(height: 8),

        // Skill groups or search results
        Expanded(
          child: _searchQuery.isEmpty
              ? _buildSkillGroups(context)
              : _buildSearchResults(context),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search skills...',
          hintStyle: EveTypography.bodyMedium(
            color: EveColors.textSecondary,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: EveColors.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: EveColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: EveColors.surfaceElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: EveTypography.bodyMedium(color: EveColors.textPrimary),
      ),
    );
  }

  Widget _buildSkillGroups(BuildContext context) {
    final groupsAsync = ref.watch(skillGroupsWithProgressProvider);

    return groupsAsync.when(
      data: (groups) {
        if (groups.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final groupWithProgress = groups[index];
            final group = groupWithProgress.group;
            final isExpanded = _expandedGroups.contains(group.groupId);

            return Column(
              children: [
                // Group header
                SkillGroupRow(
                  group: group,
                  trainedCount: groupWithProgress.trainedCount,
                  totalCount: groupWithProgress.totalCount,
                  isExpanded: isExpanded,
                  onTap: () => _toggleGroup(group.groupId),
                ),

                // Expanded skills
                if (isExpanded) _buildGroupSkills(context, group.groupId),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        Log.e(
          'SKILLS.CATALOGUE',
          'Failed to load skill groups',
          error,
          stack,
        );
        return _buildErrorState(context, error);
      },
    );
  }

  Widget _buildGroupSkills(BuildContext context, int groupId) {
    final skillsAsync = ref.watch(skillsByGroupProvider(groupId));

    return skillsAsync.when(
      data: (skills) {
        if (skills.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: skills.map((skillWithLevel) {
            return SkillCatalogueItem(
              skill: skillWithLevel.skill,
              trainedLevel: skillWithLevel.trainedLevel,
              isTraining: skillWithLevel.isTraining,
              onTap: () => _showAddToPlanDialog(
                context,
                skillWithLevel.skill,
                skillWithLevel.trainedLevel,
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stack) {
        Log.e(
          'SKILLS.CATALOGUE',
          'Failed to load skills for group $groupId',
          error,
          stack,
        );
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Failed to load skills',
            style: EveTypography.bodySmall(color: EveColors.textTertiary),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final resultsAsync = ref.watch(searchSkillsProvider(_searchQuery));

    return resultsAsync.when(
      data: (skills) {
        if (skills.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: EveColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No skills found',
                    style: EveTypography.titleLarge(color: EveColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try a different search term',
                    style: EveTypography.bodyMedium(color: EveColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: skills.length,
          itemBuilder: (context, index) {
            final skillWithLevel = skills[index];
            return SkillCatalogueItem(
              skill: skillWithLevel.skill,
              trainedLevel: skillWithLevel.trainedLevel,
              isTraining: skillWithLevel.isTraining,
              onTap: () => _showAddToPlanDialog(
                context,
                skillWithLevel.skill,
                skillWithLevel.trainedLevel,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        Log.e('SKILLS.CATALOGUE', 'Search failed', error, stack);
        return _buildErrorState(context, error);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: EveColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Skills Found',
              style: EveTypography.titleLarge(color: EveColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Skill data is loading or unavailable',
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
              color: EveColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Skills',
              style: EveTypography.titleLarge(color: EveColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: EveTypography.bodyMedium(color: EveColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
