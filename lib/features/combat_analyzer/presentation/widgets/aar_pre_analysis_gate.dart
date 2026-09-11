import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../domain/aar_evidence_assessment.dart';

class AarPreAnalysisGate extends StatelessWidget {
  const AarPreAnalysisGate({
    super.key,
    required this.assessment,
    required this.onAnalyze,
  });

  final AarEvidenceAssessment? assessment;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'COMBAT.UI',
      'AarPreAnalysisGate band=${assessment?.band.name} score=${assessment?.score}',
    );
    final button = FilledButton.icon(
      key: const Key('aar-analyze-button'),
      onPressed: onAnalyze,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Analyze With AI'),
    );

    final current = assessment;
    if (current == null) return button;

    switch (current.band) {
      case AarEvidenceBand.low:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(
              key: const Key('aar-gate-warning'),
              icon: Icons.warning_amber,
              color: EveColors.warning,
              text: current.headline,
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: button),
          ],
        );
      case AarEvidenceBand.partial:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _banner(
              key: const Key('aar-gate-advisory'),
              color: EveColors.textSecondary,
              text: current.headline,
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: button),
          ],
        );
      case AarEvidenceBand.good:
      case AarEvidenceBand.complete:
        return Row(
          children: [
            Chip(
              key: const Key('aar-gate-chip'),
              label: Text(current.scoreLabel),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            button,
          ],
        );
    }
  }

  Widget _banner({
    required Key key,
    required Color color,
    required String text,
    IconData? icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(text, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
