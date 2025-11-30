import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../core/widgets/character_avatar.dart';
import '../../../data/combat_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing PvP/PvE combat statistics from zkillboard.
///
/// Displays:
/// - Aggregate stats across all characters (kills, deaths, K/D ratio, ISK)
/// - Per-character breakdown with combat activity
/// - Danger rating color-coded (green for positive, red for negative)
///
/// Handles loading, error, and empty states gracefully.
/// zkillboard API can be unreliable - failures don't block the dashboard.
class CombatStatsCard extends ConsumerWidget {
  const CombatStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combatStatsAsync = ref.watch(allCharacterCombatStatsProvider);

    return DashboardCard(
      title: 'COMBAT STATS',
      icon: Icons.military_tech_outlined,
      glowColor: EveColors.error,
      isLoading: combatStatsAsync.isLoading,
      errorMessage: combatStatsAsync.hasError
          ? 'Failed to load combat stats from zkillboard'
          : null,
      onRetry: () => ref.invalidate(allCharacterCombatStatsProvider),
      child: combatStatsAsync.when(
        data: (stats) => _buildContent(context, ref, stats),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AggregateCombatStats stats,
  ) {
    if (!stats.hasActivity) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - ALL CHARACTERS
        Text(
          'ALL CHARACTERS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withAlpha(179),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: 12),

        // Aggregate statistics
        _buildAggregateStats(context, stats),

        if (stats.characterStats.isNotEmpty) ...[
          const SizedBox(height: 24),

          // Section header - BY CHARACTER
          Text(
            'BY CHARACTER',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withAlpha(179),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 12),

          // Per-character breakdown
          ...stats.characterStats.map((charStat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCharacterRow(context, charStat),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildAggregateStats(
    BuildContext context,
    AggregateCombatStats stats,
  ) {
    final dangerColor = stats.dangerRating >= 0 ? EveColors.success : EveColors.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kills / Deaths / K/D Ratio
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'KILLS',
                value: stats.totalKills.toString(),
                color: EveColors.success,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'DEATHS',
                value: stats.totalDeaths.toString(),
                color: EveColors.error,
                icon: Icons.cancel_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'K/D RATIO',
                value: stats.kdRatio.toStringAsFixed(2),
                color: dangerColor,
                icon: Icons.assessment_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ISK Destroyed / ISK Lost
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'ISK DESTROYED',
                value: formatIskCompact(stats.totalIskDestroyed),
                color: EveColors.success,
                icon: Icons.trending_up,
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                label: 'ISK LOST',
                value: formatIskCompact(stats.totalIskLost),
                color: EveColors.error,
                icon: Icons.trending_down,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCharacterRow(BuildContext context, CombatStatsData stats) {
    final dangerColor = stats.dangerRating >= 0 ? EveColors.success : EveColors.error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: dangerColor.withAlpha(77),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Character avatar
          CharacterAvatar(
            portraitUrl: '', // Will use placeholder
            size: CharacterAvatarSize.small,
          ),
          const SizedBox(width: 8),

          // Character name and stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stats.characterName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${stats.kills} kills / ${stats.deaths} deaths',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(179),
                      ),
                ),
              ],
            ),
          ),

          // Danger rating badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: dangerColor.withAlpha(51),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: dangerColor.withAlpha(128),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  stats.dangerRating >= 0
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  size: 14,
                  color: dangerColor,
                ),
                const SizedBox(width: 4),
                Text(
                  stats.dangerRating.abs().toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: dangerColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: Colors.white.withAlpha(77),
            ),
            const SizedBox(height: 12),
            Text(
              'No Combat Data',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(179),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your characters have no recorded combat activity',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(128),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Statistic box showing a label, value, and optional icon.
class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.compact = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withAlpha(77),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: color.withAlpha(179),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withAlpha(179),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Value
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 18 : 24,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
