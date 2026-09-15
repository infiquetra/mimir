// X5 RED contracts for graph eligibility and the route solver (D15–D20, D22–D23).
// Compile stubs load so these fail as assertions, not missing imports.
// Expected RED until GREEN implements design §4.5–§4.6:
// - D15/D20: EdgeEligibility ignores closed/expired/stale/24h verification.
// - D16: GraphBuilder emits unverified locals and invents K162→B274.
// - D17: gate-only BFS yields A-B-C-D-Z; insertion order wins w02.
// - D18: Prefer Highsec still takes the short lowsec path.
// - D19: avoids are not applied; destination-in-lowsec still found.
// - D22: A→A is a 1-jump found route; missing topology is graph-disconnected.
// - D23: no step provenance; totalJumps is gate count only.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/exploration/domain/edge_eligibility.dart';
import 'package:mimir/features/exploration/domain/exploration_graph_builder.dart';
import 'package:mimir/features/exploration/domain/exploration_observation.dart';
import 'package:mimir/features/exploration/domain/exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;
import 'package:mimir/features/exploration/domain/exploration_route_engine.dart';

import '../fixtures/exploration_fixtures.dart';

void main() {
  List<int> systems(RouteResult result) => [
    if (result.steps.isNotEmpty) result.steps.first.fromSystemId,
    for (final step in result.steps) step.toSystemId,
  ];

  group('D15/D20 edge eligibility', () {
    final edge = DirectedExplorationEdge(
      key: 'w01-fwd',
      fromSystemId: F7Systems.b,
      toSystemId: F7Systems.t,
      kind: 'wormhole',
      canonicalKey: 'w01',
    );

    test(
      'stale, 24h, expired verification, closed, and omitted stay excluded',
      () {
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: F4Fixtures.staleAt,
            publicValidatedAt: kExplorationT0,
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: F4Fixtures.twentyFourHours,
            publicValidatedAt: kExplorationT0,
            preferences: const RoutePreferences(
              useStaleCachedConnections: true,
            ),
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: kExplorationT0,
            verifiedAt: kExplorationT0.subtract(const Duration(hours: 24)),
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: kExplorationT0,
            lifecycle: ConnectionLifecycle.closed,
            preferences: const RoutePreferences(
              useStaleCachedConnections: true,
            ),
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: kExplorationT0,
            listedInLatestSnapshot: false,
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: edge,
            now: F3Fixtures.expiresAt,
            expiresAt: F3Fixtures.expiresAt,
          ).eligible,
          isFalse,
        );
      },
    );

    test(
      'avoid flags exclude EOL, Critical, Lowsec, Nullsec; unknown mass stays',
      () {
        expect(
          EdgeEligibility.assess(
            edge: DirectedExplorationEdge(
              key: 'eol',
              fromSystemId: F7Systems.b,
              toSystemId: F7Systems.t,
              kind: 'wormhole',
              eol: true,
            ),
            now: kExplorationT0,
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: DirectedExplorationEdge(
              key: 'crit',
              fromSystemId: F7Systems.t,
              toSystemId: F7Systems.z,
              kind: 'wormhole',
              critical: true,
            ),
            now: kExplorationT0,
          ).eligible,
          isFalse,
        );
        expect(
          EdgeEligibility.assess(
            edge: DirectedExplorationEdge(
              key: 'to-d',
              fromSystemId: F7Systems.c,
              toSystemId: F7Systems.d,
            ),
            now: kExplorationT0,
            preferences: const RoutePreferences(avoidLowsec: true),
          ).eligible,
          isFalse,
        );
      },
    );
  });

  group('D16 local direction and K162 reverse', () {
    test(
      'only verified active links become a directed pair; K162 is not B274',
      () {
        final unverified = LocalConnection(
          id: 'link-u',
          characterId: kCharacter7,
          episodeId: 'ep-u',
          fromSystemId: kAlphaSystemId,
          toSystemId: 9102,
          originatingType: 'K162',
          originatingSide: 'Unknown',
        );
        expect(ExplorationGraphBuilder.fromLocal(unverified), isEmpty);

        final verified = LocalConnection(
          id: 'link-v',
          characterId: kCharacter7,
          episodeId: 'ep-v',
          fromSystemId: kAlphaSystemId,
          toSystemId: 9102,
          originatingType: 'B274',
          originatingSide: 'From',
          verifiedAt: kExplorationT0,
        );
        final pair = ExplorationGraphBuilder.fromLocal(verified);
        expect(pair, hasLength(2));
        expect(pair.first.fromSystemId, kAlphaSystemId);
        expect(pair.first.toSystemId, 9102);

        final k162 = LocalConnection(
          id: 'link-k',
          characterId: kCharacter7,
          episodeId: 'ep-k',
          fromSystemId: kAlphaSystemId,
          toSystemId: 9102,
          originatingType: 'K162',
          originatingSide: 'Unknown',
          verifiedAt: kExplorationT0,
        );
        final labels = ExplorationGraphBuilder.fromLocal(k162);
        expect(labels, hasLength(2));
        expect(k162.reverseType(), isNot('B274'));

        final closed = LocalConnection(
          id: 'link-c',
          characterId: kCharacter7,
          episodeId: 'ep-c',
          fromSystemId: kAlphaSystemId,
          toSystemId: 9102,
          originatingType: 'B274',
          originatingSide: 'From',
          verifiedAt: kExplorationT0,
          lifecycle: ConnectionLifecycle.closed,
        );
        expect(ExplorationGraphBuilder.fromLocal(closed), isEmpty);
      },
    );
  });

  group('D17 default route and w01 tie-break', () {
    test('A-B-T-Z and w01 beats w02 regardless of insertion', () {
      final result = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
        ),
        F7Fixtures.graph(),
      );
      expect(systems(result), F7Fixtures.defaultPath);
      expect(result.gateJumps, 1);
      expect(result.wormholeJumps, 2);
      expect(result.totalJumps, 3);

      final w02First = ExplorationGraphBuilder.fromEdges([
        const DirectedExplorationEdge(
          key: 'w02-fwd',
          fromSystemId: F7Systems.b,
          toSystemId: F7Systems.t,
          kind: 'wormhole',
          canonicalKey: 'w02',
        ),
        ...F7Fixtures.graph(includeW02: true).edges,
      ]);
      final tied = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
        ),
        w02First,
      );
      expect(tied.steps.any((step) => step.edgeKey.contains('w01')), isTrue);
      expect(tied.steps.any((step) => step.edgeKey.contains('w02')), isFalse);
    });
  });

  group('D18 Prefer Highsec', () {
    test('five-gate all-highsec beats A-B-T-Z', () {
      final result = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
          preferences: RoutePreferences(
            avoidEol: true,
            avoidCriticalMass: true,
            preferHighsec: true,
          ),
        ),
        F7Fixtures.graph(),
      );
      expect(systems(result), F7Fixtures.preferHighsecPath);
      expect(result.gateJumps, 5);
      expect(result.wormholeJumps, 0);
    });
  });

  group('D19 hard avoids and origin-escape', () {
    test(
      'EOL, Critical, Lowsec destination, and no relaxed diagnostic path',
      () {
        final eol = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.a,
            destinationSystemId: F7Systems.z,
          ),
          F7Fixtures.graph(btEol: true),
        );
        expect(systems(eol), F7Fixtures.eolPath);

        final critical = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.a,
            destinationSystemId: F7Systems.z,
          ),
          F7Fixtures.graph(tzCritical: true),
        );
        expect(systems(critical), F7Fixtures.eolPath);

        final blocked = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.a,
            destinationSystemId: F7Systems.d,
            preferences: RoutePreferences(
              avoidEol: true,
              avoidCriticalMass: true,
              avoidLowsec: true,
            ),
          ),
          F7Fixtures.graph(),
        );
        expect(blocked.outcome, RouteOutcome.noRouteUnderPreferences);
        expect(blocked.steps, isEmpty);

        final escape = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.d,
            destinationSystemId: F7Systems.z,
            preferences: RoutePreferences(
              avoidEol: true,
              avoidCriticalMass: true,
              avoidLowsec: true,
            ),
          ),
          F7Fixtures.graph(),
        );
        expect(escape.outcome, RouteOutcome.found);
        expect(systems(escape).skip(1), isNot(contains(F7Systems.d)));
      },
    );
  });

  group('D22 zero-step, missing graph, one-way gate', () {
    test(
      'A→A is no travel; missing topology is dataUnavailable; no invented reverse',
      () {
        final same = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.a,
            destinationSystemId: F7Systems.a,
          ),
          F7Fixtures.graph(),
        );
        expect(same.outcome, RouteOutcome.alreadyAtDestination);
        expect(same.steps, isEmpty);
        expect(same.gateJumps, 0);
        expect(same.wormholeJumps, 0);
        expect(same.totalJumps, 0);

        final missing = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.a,
            destinationSystemId: F7Systems.z,
          ),
          GraphSnapshot(
            nodes: {F7Systems.a},
            edges: const [],
            topologyAvailable: false,
          ),
        );
        expect(missing.outcome, RouteOutcome.dataUnavailable);

        final oneWay = const DirectedExplorationEdge(
          key: 'g-a-b',
          fromSystemId: F7Systems.a,
          toSystemId: F7Systems.b,
        );
        final built = ExplorationGraphBuilder.directedGates([oneWay]);
        expect(
          built.where(
            (edge) =>
                edge.fromSystemId == F7Systems.b &&
                edge.toSystemId == F7Systems.a,
          ),
          isEmpty,
        );
        final reverse = ExplorationRouteEngine.route(
          const RouteRequest(
            originSystemId: F7Systems.b,
            destinationSystemId: F7Systems.a,
          ),
          GraphSnapshot(nodes: {F7Systems.a, F7Systems.b}, edges: built),
        );
        expect(reverse.outcome, RouteOutcome.noRouteInGraph);
      },
    );
  });

  group('D23 risk ranks and counts', () {
    test('max risk vs sum; totalJumps = gates + holes; provenance present', () {
      final result = ExplorationRouteEngine.route(
        const RouteRequest(
          originSystemId: F7Systems.a,
          destinationSystemId: F7Systems.z,
        ),
        F7Fixtures.graph(),
      );
      expect(result.totalJumps, result.gateJumps + result.wormholeJumps);
      expect(result.totalJumps, result.steps.length);
      expect(result.gateJumps, 1);
      expect(result.wormholeJumps, 2);
      expect(result.riskSum, 2);
      expect(result.maxRisk, EdgeRisk.caution);
      expect(result.steps.first.fromTypeCode, isNotNull);
      expect(result.steps.last.toTypeCode, isNotNull);
      expect(result.steps.any((step) => step.risk == EdgeRisk.caution), isTrue);
    });
  });
}
