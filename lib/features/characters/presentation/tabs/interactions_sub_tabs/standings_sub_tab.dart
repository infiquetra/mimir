import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/widgets/corporation_logo.dart';
import '../../../../../core/widgets/faction_logo.dart';
import '../../../../../core/widgets/standing_indicator.dart';
import '../../../data/character_providers.dart';
import '../../../data/character_status_providers.dart';

/// Standings sub-tab showing character standings with entities.
///
/// Displays:
/// - Grouped standings by type (agents, NPCs, corporations, factions)
/// - Standing value with color-coded row background tinting
/// - Entity logos (corporation/faction/agent avatars)
class StandingsSubTab extends ConsumerWidget {
  const StandingsSubTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCharacter = ref.watch(activeCharacterProvider);

    return activeCharacter.when(
      data: (character) {
        if (character == null) {
          return _buildNoCharacterState(context);
        }
        return _buildStandingsView(context, ref, character.characterId);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading character: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildNoCharacterState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No Character Selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandingsView(
    BuildContext context,
    WidgetRef ref,
    int characterId,
  ) {
    final theme = Theme.of(context);
    final standings = ref.watch(characterStandingsProvider(characterId));

    return standings.when(
      data: (standingsList) {
        if (standingsList.isEmpty) {
          return _buildEmptyState(context);
        }

        // Group standings by type
        final grouped = <String, List<dynamic>>{};
        for (final standing in standingsList) {
          grouped.putIfAbsent(standing.fromType, () => []).add(standing);
        }

        // Sort each group by standing value (highest to lowest)
        for (final group in grouped.values) {
          group.sort((a, b) => b.standing.compareTo(a.standing));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary card
              _buildSummaryCard(theme, standingsList),
              const SizedBox(height: 16),

              // Standings by type
              if (grouped.containsKey('faction'))
                _buildStandingsSection(
                  theme,
                  context,
                  'Factions',
                  Icons.flag_outlined,
                  grouped['faction']!,
                ),
              if (grouped.containsKey('npc_corp'))
                _buildStandingsSection(
                  theme,
                  context,
                  'NPC Corporations',
                  Icons.business_outlined,
                  grouped['npc_corp']!,
                ),
              if (grouped.containsKey('agent'))
                _buildStandingsSection(
                  theme,
                  context,
                  'Agents',
                  Icons.person_outlined,
                  grouped['agent']!,
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  Widget _buildSummaryCard(ThemeData theme, List<dynamic> standings) {
    final positive = standings.where((s) => s.standing > 0).length;
    final negative = standings.where((s) => s.standing < 0).length;
    final neutral = standings.where((s) => s.standing == 0).length;

    return Card(
      elevation: 0,
      color: EveColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: EveColors.evePrimary.withAlpha(51),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 20,
                  color: EveColors.evePrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Standings Summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: EveColors.evePrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Standing counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  theme,
                  'Positive',
                  positive,
                  EveColors.success,
                  Icons.trending_up,
                ),
                _buildSummaryItem(
                  theme,
                  'Neutral',
                  neutral,
                  Colors.grey,
                  Icons.trending_flat,
                ),
                _buildSummaryItem(
                  theme,
                  'Negative',
                  negative,
                  EveColors.error,
                  Icons.trending_down,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    ThemeData theme,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildStandingsSection(
    ThemeData theme,
    BuildContext context,
    String title,
    IconData icon,
    List<dynamic> standings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: EveColors.evePrimary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: EveColors.evePrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: EveColors.evePrimary.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${standings.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: EveColors.evePrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          elevation: 0,
          color: EveColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: EveColors.evePrimary.withAlpha(51),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: standings.map((standing) {
                return _buildStandingRow(context, theme, standing);
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStandingRow(BuildContext context, ThemeData theme, dynamic standing) {
    final standingValue = standing.standing as double;
    final color = _getStandingColor(standingValue);

    // Get background tint color using StandingIndicator
    final backgroundColor = StandingIndicator.getBackgroundColor(
      standingValue,
      context: context,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Entity logo/icon
          _buildEntityIcon(context, standing),
          const SizedBox(width: 12),

          // Entity name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  standing.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  StandingIndicator.getStandingLabel(standingValue),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withAlpha(179),
                  ),
                ),
              ],
            ),
          ),

          // Standing value
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                StandingIndicator.formatStanding(standingValue),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              _buildStandingBar(standingValue),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds entity-specific icon (corporation logo, faction logo, or agent avatar).
  Widget _buildEntityIcon(BuildContext context, dynamic standing) {
    final fromType = standing.fromType as String;
    final fromId = standing.fromId as int;

    if (fromType == 'faction') {
      return FactionLogo(
        factionId: fromId,
        size: 40,
        borderRadius: 8,
      );
    } else if (fromType == 'npc_corp') {
      return CorporationLogo.corporation(
        corporationId: fromId,
        size: 40,
        borderRadius: 8,
      );
    } else if (fromType == 'agent') {
      // Agents use character portrait endpoint
      final theme = Theme.of(context);
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Icon(
          Icons.person_outline,
          size: 24,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Fallback icon
    final theme = Theme.of(context);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Icon(
        Icons.help_outline,
        size: 24,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildStandingBar(double standing) {
    final normalizedValue = ((standing + 10) / 20).clamp(0.0, 1.0);
    final color = _getStandingColor(standing);

    return Container(
      width: 80,
      height: 4,
      decoration: BoxDecoration(
        color: EveColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: normalizedValue,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _getStandingColor(double standing) {
    if (standing >= 5.0) return const Color(0xFF00BFFF); // Excellent (light blue)
    if (standing >= 0.5) return EveColors.success; // Good (green)
    if (standing > -0.5) return Colors.grey; // Neutral
    if (standing > -5.0) return Colors.orange; // Bad
    return EveColors.error; // Terrible (red)
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
            ),
            const SizedBox(height: 16),
            Text(
              'No Standings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any standings yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              'Failed to load standings',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
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
