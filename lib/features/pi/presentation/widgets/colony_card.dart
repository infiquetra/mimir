import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../data/models/colony.dart';

class ColonyCard extends StatelessWidget {
  final Colony colony;
  final VoidCallback? onTap;

  const ColonyCard({
    super.key,
    required this.colony,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Log.d('PI', 'ColonyCard.build() for ${colony.planetName}');
    // In a real implementation, we'd calculate this from the extractor pins
    // For this dashboard view, we'll use fallback values if pins aren't fully loaded
    final hasExtractors = colony.pins.any((p) => p.extractorDetails != null);
    final statusColor = hasExtractors ? EveColors.success : EveColors.warning;
    final statusText = hasExtractors ? 'Extracting' : 'Idle';

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
            value: hasExtractors ? '2d 04h 30m' : 'N/A',
            icon: Icons.timer_outlined,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: 'Est. Output',
            value: hasExtractors ? '4,500 units/hr' : '0 units/hr',
            icon: Icons.show_chart_outlined,
          ),
        ],
      ),
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
