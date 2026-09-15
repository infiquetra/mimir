import 'package:flutter/material.dart';

import '../../domain/aar_fit_calculation.dart';

/// Naive metric table: publishes a winner and raw omni EHP.
class AarFitComparisonTable extends StatelessWidget {
  const AarFitComparisonTable({
    super.key,
    this.baseline,
    this.candidate,
    this.profileLabel = 'EM 100%',
  });

  final CombatFitComputation? baseline;
  final CombatFitComputation? candidate;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final baselineEhp = baseline?.stats.defenses.totalEhp ?? 0;
    final candidateEhp = candidate?.stats.defenses.totalEhp ?? 0;
    final winner = candidateEhp >= baselineEhp ? 'candidate' : 'baseline';
    return Card(
      key: const Key('aar-comparison-metrics-table'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Winner: $winner'),
          Text('Best fit'),
          Text('$baselineEhp → $candidateEhp'),
          Text(profileLabel),
        ],
      ),
    );
  }
}

class AarFitStatDeltaCards extends StatelessWidget {
  const AarFitStatDeltaCards({
    super.key,
    this.baseline,
    this.candidate,
    this.profileLabel = 'EM 100%',
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
