import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/sde/sde_database.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/theme/eve_typography.dart';
import '../../../../core/widgets/eve_skill_icon.dart';
import '../../data/skill_catalogue_providers.dart';

/// Full-screen dialog for browsing and multi-selecting skills.
///
/// Allows the user to:
/// - Browse skills by group with expand/collapse
/// - Search skills by name
/// - Multi-select skills with checkboxes
/// - Choose target level for each selected skill
/// - See count of selected skills
/// - Add selected skills to a plan
class SkillBrowserDialog extends ConsumerStatefulWidget {
  const SkillBrowserDialog({
    required this.planId,
    super.key,
  });

  final int planId;

  @override
  ConsumerState<SkillBrowserDialog> createState() =>
      _SkillBrowserDialogState();
}

class _SkillBrowserDialogState extends ConsumerState<SkillBrowserDialog> {
  // Track which groups are expanded
  final Set<int> _expandedGroups = {};

  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selected skills map: skillId -> targetLevel
  final Map<int, int> _selectedSkills = {};

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

  void _toggleSkillSelection(int skillId, int trainedLevel) {
    setState(() {
      if (_selectedSkills.containsKey(skillId)) {
        _selectedSkills.remove(skillId);
        Log.d(
          'SKILLS.BROWSER',
          'Deselected skill $skillId - ${_selectedSkills.length} skills selected',
        );
      } else {
        // Default target level is trainedLevel + 1 (or 5 if already at 5)
        final targetLevel = trainedLevel < 5 ? trainedLevel + 1 : 5;
        _selectedSkills[skillId] = targetLevel;
        Log.d(
          'SKILLS.BROWSER',
          'Selected skill $skillId (level $targetLevel) - ${_selectedSkills.length} skills selected',
        );
      }
    });
  }

  void _updateTargetLevel(int skillId, int targetLevel) {
    setState(() {
      _selectedSkills[skillId] = targetLevel;
      Log.d('SKILLS.BROWSER', 'Updated skill $skillId target level to $targetLevel');
    });
  }

  @override
  Widget build(BuildContext context) {
    Log.d('SKILLS.BROWSER', 'SkillBrowserDialog.build - START');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Skills to Plan'),
        backgroundColor: EveColors.backgroundDeep,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Log.d('SKILLS.BROWSER', 'Browser closed - cancelled');
            Navigator.of(context).pop();
          },
        ),
      ),
      backgroundColor: EveColors.backgroundBase,
      body: Column(
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

          // Selected skills summary bar
          if (_selectedSkills.isNotEmpty) _buildSelectionBar(context),
        ],
      ),
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
                _buildGroupHeader(group, groupWithProgress, isExpanded),

                // Expanded skills
                if (isExpanded) _buildGroupSkills(context, group.groupId),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        Log.e('SKILLS.BROWSER', 'Failed to load skill groups', error, stack);
        return _buildErrorState(context, error);
      },
    );
  }

  Widget _buildGroupHeader(
    SdeGroup group,
    SkillGroupWithProgress progress,
    bool isExpanded,
  ) {
    return InkWell(
      onTap: () => _toggleGroup(group.groupId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: EveColors.surfaceDefault,
          border: Border(
            bottom: BorderSide(color: EveColors.borderSubtle),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: EveColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.groupName,
                style: EveTypography.titleMedium(color: EveColors.textPrimary),
              ),
            ),
            Text(
              '${progress.trainedCount}/${progress.totalCount}',
              style: EveTypography.bodySmall(color: EveColors.textSecondary),
            ),
          ],
        ),
      ),
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
            final isSelected = _selectedSkills.containsKey(skillWithLevel.skill.typeId);
            final targetLevel = _selectedSkills[skillWithLevel.skill.typeId];

            return _SkillBrowserItem(
              skill: skillWithLevel.skill,
              trainedLevel: skillWithLevel.trainedLevel,
              isTraining: skillWithLevel.isTraining,
              isSelected: isSelected,
              targetLevel: targetLevel,
              onToggle: () => _toggleSkillSelection(
                skillWithLevel.skill.typeId,
                skillWithLevel.trainedLevel,
              ),
              onLevelChanged: (level) => _updateTargetLevel(
                skillWithLevel.skill.typeId,
                level,
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
        Log.e('SKILLS.BROWSER', 'Failed to load skills for group $groupId', error, stack);
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
            final isSelected = _selectedSkills.containsKey(skillWithLevel.skill.typeId);
            final targetLevel = _selectedSkills[skillWithLevel.skill.typeId];

            return _SkillBrowserItem(
              skill: skillWithLevel.skill,
              trainedLevel: skillWithLevel.trainedLevel,
              isTraining: skillWithLevel.isTraining,
              isSelected: isSelected,
              targetLevel: targetLevel,
              onToggle: () => _toggleSkillSelection(
                skillWithLevel.skill.typeId,
                skillWithLevel.trainedLevel,
              ),
              onLevelChanged: (level) => _updateTargetLevel(
                skillWithLevel.skill.typeId,
                level,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) {
        Log.e('SKILLS.BROWSER', 'Search failed', error, stack);
        return _buildErrorState(context, error);
      },
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: EveColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: EveColors.borderActive),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: EveColors.photonBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'} selected',
              style: EveTypography.bodyMedium(color: EveColors.textPrimary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Log.i(
                'SKILLS.BROWSER',
                'Adding ${_selectedSkills.length} skills to plan ${widget.planId}',
              );
              Navigator.of(context).pop(_selectedSkills);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: EveColors.photonBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Add Selected',
              style: EveTypography.bodyMedium(color: Colors.white),
            ),
          ),
        ],
      ),
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

/// Item widget for a skill in the browser dialog.
///
/// Shows checkbox, skill icon, name, levels, and target level selector.
class _SkillBrowserItem extends StatelessWidget {
  const _SkillBrowserItem({
    required this.skill,
    required this.trainedLevel,
    required this.isTraining,
    required this.isSelected,
    required this.targetLevel,
    required this.onToggle,
    required this.onLevelChanged,
  });

  final SdeType skill;
  final int trainedLevel;
  final bool isTraining;
  final bool isSelected;
  final int? targetLevel;
  final VoidCallback onToggle;
  final ValueChanged<int> onLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? EveColors.surfaceBright
          : EveColors.surfaceDefault,
      child: InkWell(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: EveColors.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (_) => onToggle(),
                fillColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return EveColors.photonBlue;
                  }
                  return EveColors.surfaceBright;
                }),
              ),
              const SizedBox(width: 12),

              // Skill icon
              EveSkillIcon(
                typeId: skill.typeId,
                size: 40,
              ),
              const SizedBox(width: 12),

              // Skill name and info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.typeName,
                      style: EveTypography.bodyMedium(color: EveColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Trained: Level $trainedLevel${isTraining ? ' (training)' : ''}',
                      style: EveTypography.bodySmall(
                        color: isTraining
                            ? EveColors.photonBlue
                            : EveColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Target level selector (only shown when selected)
              if (isSelected && targetLevel != null)
                _buildLevelSelector(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: EveColors.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: EveColors.borderActive),
      ),
      child: DropdownButton<int>(
        value: targetLevel,
        isDense: true,
        underline: const SizedBox.shrink(),
        dropdownColor: EveColors.surfaceElevated,
        style: EveTypography.bodySmall(color: EveColors.textPrimary),
        items: List.generate(5, (index) {
          final level = index + 1;
          final isDisabled = level <= trainedLevel;

          return DropdownMenuItem<int>(
            value: level,
            enabled: !isDisabled,
            child: Text(
              'Lv $level',
              style: EveTypography.bodySmall(
                color: isDisabled
                    ? EveColors.textDisabled
                    : EveColors.textPrimary,
              ),
            ),
          );
        }),
        onChanged: (value) {
          if (value != null && value > trainedLevel) {
            onLevelChanged(value);
          }
        },
      ),
    );
  }
}
