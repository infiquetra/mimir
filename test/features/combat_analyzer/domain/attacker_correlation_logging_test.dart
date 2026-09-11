import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/attacker_correlation_fixtures.dart';

void main() {
  group('Group I — attacker correlation logging', () {
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
      'T9.1 correlate logs [COMBAT.CORRELATE] with per-pair scores and signals',
      () {
        correlate(s2Loss());
        final pair = RegExp(
          r'\[COMBAT\.CORRELATE\].*actor=Sabre.*participant=a2.*'
          r'score=0\.50.*signals=ship,damage',
        );
        expect(
          lines.where(pair.hasMatch),
          isNotEmpty,
          reason: 'logged lines were: $lines',
        );
        expect(
          lines.where(
            (line) => line.contains(
              'correlated=3 unattributed=0 npc=0 uncorrelated=1',
            ),
          ),
          isNotEmpty,
          reason: 'logged lines were: $lines',
        );
      },
    );
  });
}
