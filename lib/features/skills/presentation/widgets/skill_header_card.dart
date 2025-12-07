import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/skill_providers.dart';

/// Header card displaying skill point summary for the active character.
///
/// Shows:
/// - Total skill points (large, prominent display)
/// - Unallocated skill points (smaller, secondary display)
/// - Loading and error states handled gracefully
///
/// This is displayed at the top of the skills screen above the tabs.
class SkillHeaderCard extends ConsumerWidget {
  const SkillHeaderCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalSpAsync = ref.watch(totalSkillPointsProvider);
    final unallocatedSpAsync = ref.watch(unallocatedSpProvider);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: EveColors.evePrimary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total SP (primary display)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Skill Points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                totalSpAsync.when(
                  data: (totalSp) => Text(
                    formatSp(totalSp),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: EveColors.evePrimary,
                    ),
                  ),
                  loading: () => SizedBox(
                    width: 200,
                    height: 32,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => Text(
                    '—',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Vertical divider
          Container(
            height: 48,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),

          // Unallocated SP (secondary display)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unallocated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                unallocatedSpAsync.when(
                  data: (unallocatedSp) => Text(
                    unallocatedSp != null ? formatSp(unallocatedSp) : '0 SP',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  loading: () => SizedBox(
                    width: 120,
                    height: 28,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  error: (_, __) => Text(
                    '—',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
