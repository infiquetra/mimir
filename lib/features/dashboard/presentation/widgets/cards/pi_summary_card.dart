import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/logging/logger.dart';
import '../../../../../core/theme/eve_colors.dart';
import '../../../../../core/theme/eve_spacing.dart';
import '../../../../../core/theme/eve_typography.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../pi/data/pi_providers.dart';
import '../dashboard_card.dart';

/// Dashboard card showing summarized PI status across all characters.
class PiSummaryCard extends ConsumerWidget {
  const PiSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coloniesAsync = ref.watch(allColoniesProvider);

    return DashboardCard(
      title: 'Planetary Industry',
      icon: Icons.public,
      glowColor: EveColors.gallente,
      isLoading: coloniesAsync.isLoading,
      errorMessage: coloniesAsync.hasError ? coloniesAsync.error.toString() : null,
      onRetry: () => ref.invalidate(allColoniesProvider),
      child: coloniesAsync.when(
        data: (colonies) => _buildContent(context, ref, colonies),
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<PlanetaryColony> colonies) {
    if (colonies.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: EveSpacing.lg),
          child: Text(
            'No active colonies.',
            style: EveTypography.bodyMedium(color: EveColors.textSecondary),
          ),
        ),
      );
    }

    // Group colonies by characterId for better organization
    final grouped = <int, List<PlanetaryColony>>{};
    for (final colony in colonies) {
      grouped.putIfAbsent(colony.characterId, () => []).add(colony);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${colonies.length} Colonies across ${grouped.length} characters',
          style: EveTypography.labelMedium(color: EveColors.textSecondary),
        ),
        SizedBox(height: EveSpacing.md),
        ...grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character ID label (could resolve name, but keeping it simple for summary)
              ...entry.value.map((colony) => Padding(
                    padding: EdgeInsets.only(bottom: EveSpacing.sm),
                    child: _ColonySummaryRow(colony: colony),
                  )),
              if (entry.key != grouped.keys.last)
                SizedBox(height: EveSpacing.xs),
            ],
          );
        }),
      ],
    );
  }
}

class _ColonySummaryRow extends ConsumerWidget {
  final PlanetaryColony colony;

  const _ColonySummaryRow({required this.colony});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pinsAsync = ref.watch(planetPinsProvider(PlanetPinsArgs(
      characterId: colony.characterId,
      planetId: colony.planetId,
    )));

    return pinsAsync.when(
      data: (pins) => _buildWithPins(context, pins),
      loading: () => _buildSkeleton(context),
      error: (_, __) => _buildError(context),
    );
  }

  Widget _buildWithPins(BuildContext context, List<PlanetaryPin> pins) {
    final extractorPins = pins.where((p) => p.productTypeId != null).toList();
    final hasActiveExtractors = extractorPins.any(
        (p) => p.expiryTime != null && p.expiryTime!.isAfter(DateTime.now()));

    final statusColor =
        hasActiveExtractors ? EveColors.success : EveColors.warning;
    final statusText = hasActiveExtractors ? 'Extracting' : 'IDLE';

    DateTime? nextCompletion;
    if (hasActiveExtractors) {
      for (final pin in extractorPins) {
        if (pin.expiryTime != null && pin.expiryTime!.isAfter(DateTime.now())) {
          if (nextCompletion == null ||
              pin.expiryTime!.isBefore(nextCompletion)) {
            nextCompletion = pin.expiryTime;
          }
        }
      }
    }

    return Row(
      children: [
        // Status indicator circle
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: statusColor.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        SizedBox(width: EveSpacing.md),

        // Planet Name
        Expanded(
          flex: 3,
          child: Text(
            colony.planetName,
            style: EveTypography.bodySmall(color: EveColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Status / Timer
        Expanded(
          flex: 2,
          child: Text(
            hasActiveExtractors && nextCompletion != null
                ? formatDuration(nextCompletion.difference(DateTime.now()))
                : statusText,
            style: EveTypography.dataSmall(
              color: hasActiveExtractors
                  ? EveColors.textSecondary
                  : EveColors.warning,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Center(
        child: LinearProgressIndicator(
          backgroundColor: EveColors.surfaceElevated,
          valueColor: AlwaysStoppedAnimation<Color>(
            EveColors.surfaceElevated.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Text(
      'Error',
      style: EveTypography.bodySmall(color: EveColors.error),
    );
  }
}
