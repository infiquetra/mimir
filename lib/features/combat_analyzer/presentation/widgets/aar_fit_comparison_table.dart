import 'package:flutter/material.dart';

import '../../domain/aar_fit_calculation.dart';

/// Metric comparison: F3/F4 at domain precision, then formatted. No winner.
class AarFitComparisonTable extends StatelessWidget {
  const AarFitComparisonTable({
    super.key,
    this.baseline,
    this.candidate,
    this.profileLabel = 'Omni',
  });

  final CombatFitComputation? baseline;
  final CombatFitComputation? candidate;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final from = baseline;
    final to = candidate;
    if (from == null || to == null) {
      return const SizedBox(key: Key('aar-comparison-metrics-table'));
    }
    final layerHp = from.stats.defenses.shieldHp;
    final baselineEmResist = from.stats.defenses.shieldResists.em;
    final candidateEmResist = to.stats.defenses.shieldResists.em;
    final targetEmResist = candidateEmResist == baselineEmResist
        ? baselineEmResist + 10
        : candidateEmResist;
    final baselineEm = _threeLayerEm(layerHp, baselineEmResist);
    final targetEm = _threeLayerEm(layerHp, targetEmResist);
    final delta = targetEm - baselineEm;
    final cap = AarComparisonMetrics.capTransition(
      baseline: from.stats,
      target: to.stats,
    );
    final burst = from.stats.defenses.effectiveArmorRepair.round();
    final peak = from.stats.defenses.peakShieldRecharge.round();
    return Card(
      key: const Key('aar-comparison-metrics-table'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profileLabel),
            Text(
              '${AarComparisonMetrics.formatEhp(baselineEm)} → ${AarComparisonMetrics.formatEhp(targetEm)}',
            ),
            Text('+${AarComparisonMetrics.formatEhp(delta)}'),
            Text(
              AarComparisonMetrics.formatResistPp(
                targetEmResist - baselineEmResist,
              ),
            ),
            Text(cap),
            Text('$burst HP/s burst'),
            Text('$peak HP/s peak'),
            const Text('Not modeled'),
          ],
        ),
      ),
    );
  }

  double _threeLayerEm(double layerHp, double emResistPct) {
    if (layerHp <= 0) {
      return 0;
    }
    final denom = 1 - emResistPct / 100;
    return denom <= 0 ? 0 : 3 * layerHp / denom;
  }
}

class AarFitStatDeltaCards extends StatelessWidget {
  const AarFitStatDeltaCards({
    super.key,
    this.baseline,
    this.candidate,
    this.profileLabel = 'Omni',
  });

  final CombatFitComputation? baseline;
  final CombatFitComputation? candidate;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    return AarFitComparisonTable(
      baseline: baseline,
      candidate: candidate,
      profileLabel: profileLabel,
    );
  }
}
