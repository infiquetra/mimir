import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  group('Group C — structural limits', () {
    const scorer = AarEvidenceScorer();

    test('T3.1 no scored dimension references range', () {
      final labels = AarEvidenceDimension.values.map((d) => d.label).toList();
      expect(
        labels.any((label) => label.toLowerCase().contains('range')),
        isFalse,
      );
      final assessment = scorer.assess(s7Inputs());
      expect(
        assessment.dimensions.every(
          (r) => !r.detail.toLowerCase().contains('range'),
        ),
        isTrue,
      );
    });

    test('T3.2 structuralLimits contains the range entry', () {
      expect(
        scorer.assess(s1Inputs()).structuralLimits,
        contains(AarStructuralLimit.range),
      );
    });

    test('T3.3 range never affects earned or available', () {
      final assessed = scorer.assess(s7Inputs());
      expect(assessed.available, 100);
      expect(assessed.earned, 100);
      final combined = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.complete,
          d4: AarEvidenceStatus.complete,
          d5: AarEvidenceStatus.complete,
        ),
      );
      expect(combined.score, assessed.score);
      expect(combined.earned, assessed.earned);
      expect(combined.available, assessed.available);
    });

    test('T3.4 a 100% assessment still lists the range limit', () {
      final assessment = scorer.assess(s7Inputs());
      expect(assessment.score, 100);
      expect(assessment.structuralLimits, hasLength(1));
    });
  });
}
