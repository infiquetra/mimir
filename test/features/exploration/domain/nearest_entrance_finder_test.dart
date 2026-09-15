// X5 RED contracts for nearest entrance (D21 / F8).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §4.7:
// - mixed-graph hops instead of gate-only approach + entry edge
// - Avoid Lowsec still uses E→U
// - already-in-hub copy is generic
// - isolated J origin reports distance 0
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;
import 'package:mimir/features/exploration/domain/nearest_entrance_finder.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  group('D21 F8 nearest entrance', () {
    test(
      'B→T on risk tie-break; Avoid-Lowsec rejects E→U; 5-gate fallback',
      () {
        final nearest = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.t,
          graph: F7Fixtures.graph(),
        );
        expect(nearest.found, isTrue);
        expect(nearest.approachSystemId, F7Systems.b);
        expect(nearest.gateJumps, 1);
        expect(nearest.wormholeJumps, 1);
        expect(nearest.summary, F8Fixtures.bToTSummary);

        final avoidLow = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.u,
          graph: F7Fixtures.graph(),
          preferences: const RoutePreferences(
            avoidEol: true,
            avoidCriticalMass: true,
            avoidLowsec: true,
          ),
        );
        expect(avoidLow.found, isFalse);

        final fallback = NearestEntranceFinder.find(
          originSystemId: F7Systems.a,
          hubSystemId: F7Systems.t,
          graph: F7Fixtures.graph(btEol: true),
          preferences: const RoutePreferences(
            avoidEol: true,
            avoidCriticalMass: true,
            avoidLowsec: true,
          ),
        );
        expect(fallback.gateJumps, 5);
        expect(fallback.wormholeJumps, 1);
        expect(fallback.summary, F8Fixtures.zVia5GatesSummary);
      },
    );

    test('already in Thera is per-hub; isolated J is not distance 0', () {
      final here = NearestEntranceFinder.find(
        originSystemId: F7Systems.t,
        hubSystemId: F7Systems.t,
        graph: F7Fixtures.graph(),
      );
      expect(here.alreadyInHub, isTrue);
      expect(here.summary, 'Already in Thera');

      final otherHub = NearestEntranceFinder.find(
        originSystemId: F7Systems.t,
        hubSystemId: F7Systems.u,
        graph: F7Fixtures.graph(),
      );
      expect(otherHub.alreadyInHub, isFalse);

      final isolated = NearestEntranceFinder.find(
        originSystemId: F7Systems.j,
        hubSystemId: F7Systems.t,
        graph: F7Fixtures.graph(),
      );
      expect(isolated.found, isFalse);
      expect(isolated.gateJumps, isNot(0));
    });
  });
}
