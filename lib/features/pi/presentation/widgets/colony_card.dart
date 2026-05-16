import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/eve_card.dart';
import '../../../../core/widgets/eve_type_icon.dart';
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
      glowColor: statusColor.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedPlanet(
            planetType: colony.planetType,
            pins: pins,
          ),
          const SizedBox(width: 24),
          Expanded(
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
                                      .withOpacity(0.7),
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

class AnimatedPlanet extends StatefulWidget {
  final String planetType;
  final List<PlanetaryPin> pins;

  const AnimatedPlanet({
    required this.planetType,
    required this.pins,
    super.key,
  });

  @override
  State<AnimatedPlanet> createState() => _AnimatedPlanetState();
}

class _AnimatedPlanetState extends State<AnimatedPlanet> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  int _getPlanetTypeId(String planetType) {
    switch (planetType.toLowerCase()) {
      case 'temperate': return 11;
      case 'ice': return 12;
      case 'gas': return 13;
      case 'oceanic': return 2014;
      case 'lava': return 2015;
      case 'barren': return 2016;
      case 'storm': return 2017;
      case 'plasma': return 2063;
      default: return 11;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeId = _getPlanetTypeId(widget.planetType);
    final extractors = widget.pins.where((p) => p.productTypeId != null).toList();
    final hasActive = extractors.any(
      (p) => p.expiryTime != null && p.expiryTime!.isAfter(DateTime.now()),
    );
    final glowColor = hasActive ? EveColors.success : EveColors.warning;

    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing glow ring
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowOpacity = 0.15 + (_glowController.value * 0.35);
              final glowSpread = 2.0 + (_glowController.value * 6.0);
              return Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withOpacity(glowOpacity),
                      blurRadius: 12,
                      spreadRadius: glowSpread,
                    ),
                  ],
                ),
              );
            },
          ),
          // Static planet texture
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: EveTypeIcon(typeId: typeId, size: 128),
                ),
                // Extractor pin dots
                ...extractors.map((pin) {
                  final hash = pin.pinId.hashCode;
                  final angle = (hash % 360) * (math.pi / 180);
                  final r = 35.0;
                  final x = r * math.cos(angle);
                  final y = r * math.sin(angle);

                  final isActive = pin.expiryTime != null && pin.expiryTime!.isAfter(DateTime.now());
                  final pinColor = isActive ? EveColors.success : EveColors.warning;

                  return Positioned(
                    left: 40 + x - 3,
                    top: 40 + y - 3,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: pinColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withOpacity(0.8),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Static shadow overlay for 3D depth
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                radius: 0.8,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
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
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
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
        Icon(icon, size: 16, color: EveColors.evePrimary.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
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
