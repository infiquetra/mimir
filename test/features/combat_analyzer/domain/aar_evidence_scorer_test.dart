import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  group('Group A — AarEvidenceScorer', () {
    const scorer = AarEvidenceScorer();

    test('T1.1 weights sum to 100', () {
      expect(
        AarEvidenceRules.weights.values.fold<int>(0, (sum, w) => sum + w),
        100,
      );
      expect(AarEvidenceDimension.values, hasLength(5));
    });

    test('T1.2 all Complete → 100, Complete, not capped', () {
      final assessment = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.complete,
          d4: AarEvidenceStatus.complete,
          d5: AarEvidenceStatus.complete,
        ),
      );
      expect(assessment.score, 100);
      expect(assessment.band, AarEvidenceBand.complete);
      expect(assessment.capped, isFalse);
      expect(assessment.bandLabel, 'Complete');
      expect(assessment.available, 100);
    });

    test('T1.3 S1 fixture → 49 Partial', () {
      final assessment = scorer.assess(s1Inputs());
      expect(assessment.score, 49);
      expect(assessment.band, AarEvidenceBand.partial);
      expect(assessment.earned, 48.5);
      expect(assessment.available, 100);
      expect(assessment.dimensions.map((r) => r.status).toList(), [
        AarEvidenceStatus.missing,
        AarEvidenceStatus.complete,
        AarEvidenceStatus.complete,
        AarEvidenceStatus.inferred,
        AarEvidenceStatus.partial,
      ]);
    });

    test('T1.4 S1 + pilot fit Complete → 79 Good', () {
      expect(
        scorer
            .assess(s1Inputs())
            .projectedScoreIf(
              AarEvidenceDimension.pilotFit,
              AarEvidenceStatus.complete,
            ),
        79,
      );
      final combined = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.complete,
          d4: AarEvidenceStatus.inferred,
          d5: AarEvidenceStatus.partial,
        ),
      );
      expect(combined.score, 79);
      expect(combined.band, AarEvidenceBand.good);
    });

    test('T1.5 all Missing except log → 20 Low', () {
      final assessment = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.missing,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.missing,
          d4: AarEvidenceStatus.missing,
          d5: AarEvidenceStatus.missing,
        ),
      );
      expect(assessment.score, 20);
      expect(assessment.band, AarEvidenceBand.low);
    });

    test('T1.6 D3+D4 Unavailable → denominator 65, 100 capped', () {
      final assessment = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.unavailable,
          d4: AarEvidenceStatus.unavailable,
          d5: AarEvidenceStatus.complete,
        ),
      );
      expect(assessment.available, 65);
      expect(assessment.earned, 65);
      expect(assessment.score, 100);
      expect(assessment.capped, isTrue);
      expect(assessment.bandLabel, 'Complete (capped)');
    });

    test('T1.7 all Unavailable → 0, no divide-by-zero', () {
      final assessment = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.unavailable,
          d2: AarEvidenceStatus.unavailable,
          d3: AarEvidenceStatus.unavailable,
          d4: AarEvidenceStatus.unavailable,
          d5: AarEvidenceStatus.unavailable,
        ),
      );
      expect(assessment.available, 0);
      expect(assessment.score, 0);
      expect(assessment.capped, isTrue);
      expect(assessment.band, AarEvidenceBand.low);
    });

    test('T1.8 determinism over 100 invocations', () {
      final first = scorer.assess(s1Inputs());
      for (var i = 0; i < 100; i++) {
        final next = scorer.assess(s1Inputs());
        expect(next.score, first.score);
        expect(next.bandLabel, first.bandLabel);
        expect(
          next.ordered.map((r) => (r.dimension, r.status, r.detail)).toList(),
          first.ordered.map((r) => (r.dimension, r.status, r.detail)).toList(),
        );
      }
    });

    test(
      'T1.9 monotonic per dimension over Missing<Inferred<Partial<Complete',
      () {
        const ladder = [
          AarEvidenceStatus.missing,
          AarEvidenceStatus.inferred,
          AarEvidenceStatus.partial,
          AarEvidenceStatus.complete,
        ];
        for (final target in AarEvidenceDimension.values) {
          final others = AarEvidenceDimension.values
              .where((d) => d != target)
              .toList();
          void walk(
            int index,
            Map<AarEvidenceDimension, AarEvidenceStatus> assigned,
          ) {
            if (index == others.length) {
              for (var step = 0; step < ladder.length - 1; step++) {
                assigned[target] = ladder[step];
                final before = AarEvidenceScorer.combine(_rowsFrom(assigned));
                assigned[target] = ladder[step + 1];
                final after = AarEvidenceScorer.combine(_rowsFrom(assigned));
                expect(
                  after.score,
                  greaterThanOrEqualTo(before.score),
                  reason:
                      '$target ${ladder[step].name} → ${ladder[step + 1].name} '
                      'lowered score ${before.score} → ${after.score} for $assigned',
                );
              }
              return;
            }
            for (final status in ladder) {
              assigned[others[index]] = status;
              walk(index + 1, assigned);
            }
          }

          walk(0, <AarEvidenceDimension, AarEvidenceStatus>{});
        }
      },
    );

    test('T1.10 credits match §3.3', () {
      expect(AarEvidenceStatus.complete.credit, 1.0);
      expect(AarEvidenceStatus.partial.credit, 0.5);
      expect(AarEvidenceStatus.inferred.credit, 0.3);
      expect(AarEvidenceStatus.missing.credit, 0.0);
      expect(AarEvidenceStatus.unavailable.credit, isNull);
    });

    test(
      'A.11 ordering: Missing → Partial → Inferred → Complete → Unavailable, weight desc inside',
      () {
        final assessment = AarEvidenceScorer.combine(
          rows(
            d1: AarEvidenceStatus.missing,
            d2: AarEvidenceStatus.partial,
            d3: AarEvidenceStatus.missing,
            d4: AarEvidenceStatus.complete,
            d5: AarEvidenceStatus.unavailable,
          ),
        );
        expect(assessment.ordered.map((r) => r.dimension).toList(), [
          AarEvidenceDimension.pilotFit,
          AarEvidenceDimension.opponentIdentity,
          AarEvidenceDimension.combatLog,
          AarEvidenceDimension.opponentFit,
          AarEvidenceDimension.damageProfile,
        ]);
      },
    );

    test('A.12 topGap is the highest-weight Missing row', () {
      expect(
        scorer.assess(s1Inputs()).topGap?.dimension,
        AarEvidenceDimension.pilotFit,
      );
      expect(scorer.assess(s7Inputs()).topGap, isNull);
    });

    test('A.13 pointsToComplete', () {
      final s1 = scorer.assess(s1Inputs());
      expect(s1[AarEvidenceDimension.pilotFit].pointsToComplete, 30);
      expect(s1[AarEvidenceDimension.damageProfile].pointsToComplete, 8);
      expect(s1[AarEvidenceDimension.opponentFit].pointsToComplete, 14);
      expect(s1[AarEvidenceDimension.combatLog].pointsToComplete, 0);
      final unavailable = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.unavailable,
          d4: AarEvidenceStatus.unavailable,
          d5: AarEvidenceStatus.complete,
        ),
      );
      expect(
        unavailable[AarEvidenceDimension.opponentIdentity].pointsToComplete,
        0,
      );
      expect(unavailable[AarEvidenceDimension.opponentFit].pointsToComplete, 0);
    });

    test('A.14 combine rejects duplicate or missing dimensions', () {
      expect(
        () => AarEvidenceScorer.combine(
          rows(
            d1: AarEvidenceStatus.complete,
            d2: AarEvidenceStatus.complete,
            d3: AarEvidenceStatus.complete,
            d4: AarEvidenceStatus.complete,
            d5: AarEvidenceStatus.complete,
          ).take(4).toList(),
        ),
        throwsArgumentError,
      );
      expect(
        () => AarEvidenceScorer.combine([
          row(AarEvidenceDimension.pilotFit, AarEvidenceStatus.complete),
          row(AarEvidenceDimension.pilotFit, AarEvidenceStatus.missing),
          row(AarEvidenceDimension.combatLog, AarEvidenceStatus.complete),
          row(
            AarEvidenceDimension.opponentIdentity,
            AarEvidenceStatus.complete,
          ),
          row(AarEvidenceDimension.opponentFit, AarEvidenceStatus.complete),
        ]),
        throwsArgumentError,
      );
    });

    test('A.15 rounding is half-up', () {
      expect(
        AarEvidenceScorer.combine(
          rows(
            d1: AarEvidenceStatus.missing,
            d2: AarEvidenceStatus.complete,
            d3: AarEvidenceStatus.complete,
            d4: AarEvidenceStatus.inferred,
            d5: AarEvidenceStatus.partial,
          ),
        ).score,
        49,
      );
      expect(
        AarEvidenceScorer.combine(
          rows(
            d1: AarEvidenceStatus.complete,
            d2: AarEvidenceStatus.complete,
            d3: AarEvidenceStatus.complete,
            d4: AarEvidenceStatus.inferred,
            d5: AarEvidenceStatus.partial,
          ),
        ).score,
        79,
      );
    });

    test('A.16 headline copy per band', () {
      final low = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.missing,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.missing,
          d4: AarEvidenceStatus.partial,
          d5: AarEvidenceStatus.missing,
        ),
      );
      expect(low.score, 30);
      expect(
        low.headline,
        startsWith(
          'Analysis at 30% evidence will produce general coaching, not specific fit advice.',
        ),
      );
      expect(
        low.headline,
        contains('Attaching your fit would raise this to about 60%.'),
      );

      expect(
        scorer.assess(s1Inputs()).headline,
        'Analysis will cover damage and timeline. Fit-specific conclusions will be limited.',
      );

      final good = AarEvidenceScorer.combine(
        rows(
          d1: AarEvidenceStatus.complete,
          d2: AarEvidenceStatus.complete,
          d3: AarEvidenceStatus.complete,
          d4: AarEvidenceStatus.inferred,
          d5: AarEvidenceStatus.partial,
        ),
      );
      expect(good.score, 79);
      expect(
        good.headline,
        'Most conclusions are supported; minor gaps remain.',
      );

      expect(
        scorer.assess(s7Inputs()).headline,
        'Fit-specific, quantitative conclusions are available.',
      );

      final capped = scorer.assess(s6Inputs());
      final firstUnavailable = capped.dimensions.firstWhere(
        (r) => r.status == AarEvidenceStatus.unavailable,
      );
      expect(capped.headline, endsWith(firstUnavailable.detail));
    });
  });
}

List<AarEvidenceDimensionResult> _rowsFrom(
  Map<AarEvidenceDimension, AarEvidenceStatus> assigned,
) {
  return [
    for (final dimension in AarEvidenceDimension.values)
      row(dimension, assigned[dimension]!),
  ];
}
