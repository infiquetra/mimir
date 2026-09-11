import 'package:flutter/material.dart';

import '../../../../core/logging/logger.dart';
import '../../../../core/theme/eve_colors.dart';
import '../../domain/aar_evidence_assessment.dart';

class AarReportProvenanceBanner extends StatelessWidget {
  const AarReportProvenanceBanner({
    super.key,
    this.recorded,
    this.current,
    this.currentScore,
    this.onReanalyze,
  });

  final AarEvidenceSnapshot? recorded;
  final AarEvidenceAssessment? current;
  final int? currentScore;
  final VoidCallback? onReanalyze;

  @override
  Widget build(BuildContext context) {
    Log.d(
      'COMBAT.UI',
      'AarReportProvenanceBanner recorded=${recorded?.score} '
          'current=${current?.score ?? currentScore}',
    );
    final snapshot = recorded;
    if (snapshot == null) {
      return const Text(
        'Evidence at generation: not recorded',
        key: Key('aar-provenance-not-recorded'),
        style: TextStyle(color: EveColors.textSecondary),
      );
    }

    final score = current?.score ?? currentScore;
    final offerReanalysis =
        score != null && snapshot.shouldOfferReanalysis(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          key: const Key('aar-provenance-recorded'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This report was generated at ${snapshot.label} evidence.',
              style: const TextStyle(color: EveColors.textSecondary),
            ),
            if (offerReanalysis)
              Text(
                'Evidence is now $score%.',
                style: const TextStyle(color: EveColors.textPrimary),
              ),
          ],
        ),
        if (offerReanalysis && onReanalyze != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              key: const Key('aar-provenance-reanalyze'),
              onPressed: onReanalyze,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Re-analyze'),
            ),
          ),
      ],
    );
  }
}
