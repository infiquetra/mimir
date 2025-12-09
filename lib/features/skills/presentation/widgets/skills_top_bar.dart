import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../data/skill_catalogue_providers.dart';

/// Top bar for the skills screen combining multiple controls.
///
/// Displays:
/// - Tab bar for Skill Plans / Skill Catalogue (left)
/// - Filter dropdown (right)
/// - Search field (far right)
///
/// Uses TabController passed from parent for tab management.
class SkillsTopBar extends ConsumerWidget {
  const SkillsTopBar({
    super.key,
    required this.tabController,
  });

  final TabController tabController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('SKILLS.UI', 'SkillsTopBar - building');
    final theme = Theme.of(context);
    final filterMode = ref.watch(skillFilterModeProvider);
    final searchQuery = ref.watch(skillSearchQueryProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.surfaceDefault,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          // Tab bar
          TabBar(
            controller: tabController,
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorColor: EveColors.photonBlue,
            labelColor: EveColors.photonBlue,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            labelStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: theme.textTheme.labelLarge,
            tabs: const [
              Tab(text: 'Skill Plans'),
              Tab(text: 'Skill Catalogue'),
            ],
          ),

          const Spacer(),

          // Filter dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: EveColors.surfaceElevated,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: DropdownButton<SkillFilterMode>(
              value: filterMode,
              onChanged: (newMode) {
                if (newMode != null) {
                  Log.d('SKILLS.UI', 'SkillsTopBar - filter changed to $newMode');
                  ref.read(skillFilterModeProvider.notifier).state = newMode;
                }
              },
              underline: const SizedBox.shrink(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              style: theme.textTheme.bodySmall,
              dropdownColor: EveColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              items: [
                DropdownMenuItem(
                  value: SkillFilterMode.all,
                  child: Row(
                    children: [
                      Icon(
                        Icons.list_alt,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Text('All Skills'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SkillFilterMode.mySkills,
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Text('My Skills'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SkillFilterMode.canTrain,
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Text('Can Train Now'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: SkillFilterMode.havePrereqs,
                  child: Row(
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      const Text('Have Prerequisites'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Search field
          SizedBox(
            width: 250,
            child: TextField(
              controller: TextEditingController(text: searchQuery),
              onChanged: (value) {
                Log.d('SKILLS.UI', 'SkillsTopBar - search query: $value');
                ref.read(skillSearchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Search skills...',
                hintStyle: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          Log.d('SKILLS.UI', 'SkillsTopBar - clear search');
                          ref.read(skillSearchQueryProvider.notifier).state = '';
                        },
                      )
                    : null,
                filled: true,
                fillColor: EveColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: EveColors.photonBlue,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
