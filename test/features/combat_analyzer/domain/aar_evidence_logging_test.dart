import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/aar_evidence_scorer.dart';

import '../fixtures/aar_evidence_fixtures.dart';

void main() {
  group('Group I — AAR evidence logging', () {
    final lines = <String>[];
    DebugPrintCallback? prior;

    setUp(() {
      lines.clear();
      prior = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        lines.add(message ?? '');
      };
    });

    tearDown(() {
      debugPrint = prior ?? debugPrint;
    });

    test(
      'T9.1 assess emits [AAR.EVIDENCE] info with score, band, and statuses',
      () {
        const AarEvidenceScorer().assess(s1Inputs());
        final pattern = RegExp(
          r'^\[AAR\.EVIDENCE\] ℹ️ score=49 band=partial capped=false '
          r'pilotFit=missing combatLog=complete opponentIdentity=complete '
          r'opponentFit=inferred damageProfile=partial$',
        );
        expect(
          lines.where(pattern.hasMatch),
          isNotEmpty,
          reason: 'logged lines were: $lines',
        );
      },
    );
  });
}
