import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_assessment.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';
import 'package:mimir/features/combat_analyzer/presentation/widgets/aar_pre_analysis_gate.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Group G — AarPreAnalysisGate', () {
    final low30 = AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.missing,
        d2: AarEvidenceStatus.complete,
        d3: AarEvidenceStatus.missing,
        d4: AarEvidenceStatus.partial,
        d5: AarEvidenceStatus.missing,
      ),
    );
    final partial64 = AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.partial,
        d2: AarEvidenceStatus.complete,
        d3: AarEvidenceStatus.complete,
        d4: AarEvidenceStatus.inferred,
        d5: AarEvidenceStatus.partial,
      ),
    );
    final good79 = AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.complete,
        d2: AarEvidenceStatus.complete,
        d3: AarEvidenceStatus.complete,
        d4: AarEvidenceStatus.inferred,
        d5: AarEvidenceStatus.partial,
      ),
    );
    final allMissing = AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.missing,
        d2: AarEvidenceStatus.missing,
        d3: AarEvidenceStatus.missing,
        d4: AarEvidenceStatus.missing,
        d5: AarEvidenceStatus.missing,
      ),
    );
    final allComplete = AarEvidenceScorer.combine(
      rows(
        d1: AarEvidenceStatus.complete,
        d2: AarEvidenceStatus.complete,
        d3: AarEvidenceStatus.complete,
        d4: AarEvidenceStatus.complete,
        d5: AarEvidenceStatus.complete,
      ),
    );

    Future<void> pumpGate(
      WidgetTester tester,
      AarEvidenceAssessment? assessment, {
      required VoidCallback onAnalyze,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AarPreAnalysisGate(
              assessment: assessment,
              onAnalyze: onAnalyze,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets(
      'T7.1 low band renders a warning naming pilot fit above the button',
      (tester) async {
        expect(low30.score, 30);
        await pumpGate(tester, low30, onAnalyze: () {});
        expect(find.byKey(const Key('aar-gate-warning')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('aar-gate-warning')),
            matching: find.textContaining(
              'Attaching your fit would raise this to about 60%.',
            ),
          ),
          findsOneWidget,
        );
        expect(
          tester.getTopLeft(find.byKey(const Key('aar-gate-warning'))).dy,
          lessThan(
            tester.getTopLeft(find.byKey(const Key('aar-analyze-button'))).dy,
          ),
        );
      },
    );

    testWidgets('T7.2 partial band renders an advisory, not a warning', (
      tester,
    ) async {
      expect(partial64.score, 64);
      await pumpGate(tester, partial64, onAnalyze: () {});
      expect(find.byKey(const Key('aar-gate-advisory')), findsOneWidget);
      expect(find.byKey(const Key('aar-gate-warning')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('aar-gate-advisory')),
          matching: find.text(
            'Analysis will cover damage and timeline. Fit-specific conclusions will be limited.',
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('T7.3 good band renders neither; the chip does', (
      tester,
    ) async {
      expect(good79.score, 79);
      await pumpGate(tester, good79, onAnalyze: () {});
      expect(find.byKey(const Key('aar-gate-warning')), findsNothing);
      expect(find.byKey(const Key('aar-gate-advisory')), findsNothing);
      expect(find.byKey(const Key('aar-gate-chip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('aar-gate-chip')),
          matching: find.text('79% Good'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'T7.4 analyze button enabled at 0, 30, 64, 79, 100 and for null',
      (tester) async {
        final cases = <AarEvidenceAssessment?>[
          allMissing,
          low30,
          partial64,
          good79,
          allComplete,
          null,
        ];
        expect(allMissing.score, 0);
        expect(allComplete.score, 100);
        for (final assessment in cases) {
          var taps = 0;
          await pumpGate(tester, assessment, onAnalyze: () => taps++);
          final button = tester.widget<FilledButton>(
            find.byKey(const Key('aar-analyze-button')),
          );
          expect(button.enabled, isTrue);
          await tester.tap(find.byKey(const Key('aar-analyze-button')));
          await tester.pump();
          expect(taps, 1);
        }
      },
    );

    testWidgets('T7.5 no dialog at any score', (tester) async {
      for (final assessment in <AarEvidenceAssessment?>[
        allMissing,
        low30,
        partial64,
        good79,
        allComplete,
        null,
      ]) {
        await pumpGate(tester, assessment, onAnalyze: () {});
        await tester.tap(find.byKey(const Key('aar-analyze-button')));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(Dialog), findsNothing);
      }
    });

    testWidgets('G.6 capped label survives in the chip', (tester) async {
      final capped = const AarEvidenceScorer().assess(s6Inputs());
      expect(capped.score, 100);
      expect(capped.capped, isTrue);
      await pumpGate(tester, capped, onAnalyze: () {});
      expect(find.byKey(const Key('aar-gate-chip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('aar-gate-chip')),
          matching: find.text('100% Complete (capped)'),
        ),
        findsOneWidget,
      );
    });
  });
}
