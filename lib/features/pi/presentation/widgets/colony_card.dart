import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../data/pi_providers.dart';

class ColonyCard extends ConsumerWidget {
  final PlanetaryColony colony;
  final VoidCallback? onTap;

  const ColonyCard({
    super.key,
    required this.colony,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Log.d('PI', 'ColonyCard.build() for ${colony.planetName}');

    final pinsAsync = ref.watch(planetPinsProvider(PlanetPinsArgs(
      characterId: colony.characterId,
      planetId: colony.planetId,
    )));

    return pinsAsync.when(
      data: (pins) => _buildWithPins(context, pins),
      loading: () => _buildLoading(context),
      error: (err, stack) => _buildError(context, err),
    );
  }

  Widget _buildWithPins(BuildContext context, List<PlanetaryPin> pins) {
    final extractorPins = pins.where((p) => p.productTypeId != null).toList();
    final hasActiveExtractors = extractorPins
        .any((p) => p.expiryTime != null && p.expiryTime!.isAfter(DateTime.now()));

    final statusColor =
        hasActiveExtractors ? EveColors.success : EveColors.warning;
    final statusText = hasActiveExtractors ? 'Extracting' : 'Idle';

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

    return EveCard(
      onTap: onTap,
      glowColor: statusColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      colony.planetName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      colony.planetType,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ),
              ),
              _StatusIndicator(color: statusColor, text: statusText),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Upgrade Level',
            value: 'Level ${colony.upgradeLevel}',
            icon: Icons.vertical_align_top,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Active Pins',
            value: '${colony.numPins}',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Next Completion',
            value: nextCompletion != null
                ? formatDuration(nextCompletion.difference(DateTime.now()))
                : 'N/A',
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Extractors',
            value: '${extractorPins.length}',
            icon: Icons.show_chart_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const EveCard(
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return EveCard(
      child: Center(child: Text('Error: $error')),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusIndicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: EveColors.evePrimary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
