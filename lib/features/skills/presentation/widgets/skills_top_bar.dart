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
          // Tab bar - limited width to prevent overflow
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: TabBar(
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
                Tab(text: 'Catalogue'),
              ],
            ),
          ),

          const Spacer(),

          // Filter dropdown
          _buildFilterDropdown(context, ref, filterMode),

          const SizedBox(width: 12),

          // Search field - flexible width
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: _buildSearchField(context, ref, searchQuery),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(BuildContext context, WidgetRef ref, SkillFilterMode filterMode) {
    final theme = Theme.of(context);
    return Container(
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
        items: SkillFilterMode.values.map((mode) {
          return DropdownMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFilterIcon(mode),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(_getFilterLabel(mode)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _getFilterIcon(SkillFilterMode mode) {
    return switch (mode) {
      SkillFilterMode.all => Icons.list_alt,
      SkillFilterMode.mySkills => Icons.check_circle_outline,
      SkillFilterMode.canTrain => Icons.school_outlined,
      SkillFilterMode.havePrereqs => Icons.done_all,
    };
  }

  String _getFilterLabel(SkillFilterMode mode) {
    return switch (mode) {
      SkillFilterMode.all => 'All Skills',
      SkillFilterMode.mySkills => 'My Skills',
      SkillFilterMode.canTrain => 'Can Train',
      SkillFilterMode.havePrereqs => 'Prereqs Met',
    };
  }

  Widget _buildSearchField(BuildContext context, WidgetRef ref, String searchQuery) {
    final theme = Theme.of(context);
    return TextField(
      onChanged: (value) {
        Log.d('SKILLS.UI', 'SkillsTopBar - search query: $value');
        ref.read(skillSearchQueryProvider.notifier).state = value;
      },
      decoration: InputDecoration(
        hintText: 'Search...',
        hintStyle: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => ref.read(skillSearchQueryProvider.notifier).state = '',
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
      style: theme.textTheme.bodySmall,
    );
  }
}
