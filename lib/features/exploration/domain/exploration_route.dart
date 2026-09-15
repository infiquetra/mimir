import 'exploration_reference.dart';

enum OriginMode { manual, currentCharacter, lastKnownCharacter, unselected }

enum RouteOutcome {
  found,
  alreadyAtDestination,
  noRouteUnderPreferences,
  noRouteInGraph,
  dataUnavailable,
}

enum EdgeRisk { lower, caution, high, veryHigh }

sealed class OriginSelection {
  const OriginSelection();
}

class ManualOrigin extends OriginSelection {
  const ManualOrigin(this.systemId);
  final int systemId;
}

class CurrentCharacterOrigin extends OriginSelection {
  const CurrentCharacterOrigin({
    required this.characterId,
    required this.systemId,
    required this.observedAt,
  });
  final int characterId;
  final int systemId;
  final DateTime observedAt;
}

class LastKnownCharacterOrigin extends OriginSelection {
  const LastKnownCharacterOrigin({
    required this.characterId,
    required this.systemId,
    required this.observedAt,
  });
  final int characterId;
  final int systemId;
  final DateTime observedAt;
}

class UnselectedOrigin extends OriginSelection {
  const UnselectedOrigin();
}

class RoutePreferences {
  const RoutePreferences({
    this.avoidEol = false,
    this.avoidCriticalMass = false,
    this.avoidLowsec = false,
    this.avoidNullsec = false,
    this.preferHighsec = false,
    this.useStaleCachedConnections = false,
  });

  final bool avoidEol;
  final bool avoidCriticalMass;
  final bool avoidLowsec;
  final bool avoidNullsec;
  final bool preferHighsec;
  final bool useStaleCachedConnections;

  static const defaults = RoutePreferences();

  Map<String, dynamic> toJson() => {
    'avoidEol': avoidEol,
    'avoidCriticalMass': avoidCriticalMass,
    'avoidLowsec': avoidLowsec,
    'avoidNullsec': avoidNullsec,
    'preferHighsec': preferHighsec,
    'useStaleCachedConnections': useStaleCachedConnections,
  };
}

class DirectedExplorationEdge {
  const DirectedExplorationEdge({
    required this.key,
    required this.fromSystemId,
    required this.toSystemId,
    this.kind = 'gate',
    this.eol = false,
    this.critical = false,
    this.privateOwner,
    this.canonicalKey,
  });

  final String key;
  final int fromSystemId;
  final int toSystemId;
  final String kind;
  final bool eol;
  final bool critical;
  final int? privateOwner;
  final String? canonicalKey;
}

class EdgeAssessment {
  const EdgeAssessment({
    required this.edge,
    this.eligible = true,
    this.reason,
    this.risk = EdgeRisk.caution,
  });

  final DirectedExplorationEdge edge;
  final bool eligible;
  final String? reason;
  final EdgeRisk risk;
}

class GraphSnapshot {
  GraphSnapshot({
    required this.nodes,
    required this.edges,
    this.capturedAt,
    this.referenceRevision = 0,
    this.publicRevision = 0,
    this.characterId,
  });

  final Set<int> nodes;
  final List<DirectedExplorationEdge> edges;
  final DateTime? capturedAt;
  final int referenceRevision;
  final int publicRevision;
  final int? characterId;
}

class RouteRequest {
  const RouteRequest({
    required this.originSystemId,
    required this.destinationSystemId,
    this.characterId,
    this.preferences = RoutePreferences.defaults,
    this.operationId = 'route',
    this.calculatedAt,
  });

  final int originSystemId;
  final int destinationSystemId;
  final int? characterId;
  final RoutePreferences preferences;
  final String operationId;
  final DateTime? calculatedAt;
}

class RouteStep {
  const RouteStep({
    required this.fromSystemId,
    required this.toSystemId,
    required this.edgeKey,
    this.kind = 'gate',
  });

  final int fromSystemId;
  final int toSystemId;
  final String edgeKey;
  final String kind;
}

class RouteResult {
  const RouteResult({
    required this.outcome,
    this.steps = const [],
    this.gateJumps = 0,
    this.wormholeJumps = 0,
    this.riskSum = 0,
    this.maxRisk = EdgeRisk.lower,
    this.fingerprint = '',
    this.limitations = const [],
    this.calculatedAt,
    this.outdated = false,
  });

  final RouteOutcome outcome;
  final List<RouteStep> steps;
  final int gateJumps;
  final int wormholeJumps;
  final int riskSum;
  final EdgeRisk maxRisk;
  final String fingerprint;
  final List<String> limitations;
  final DateTime? calculatedAt;
  final bool outdated;

  int get totalJumps => steps.length;
}

class NearestEntranceOutcome {
  const NearestEntranceOutcome({
    this.approachSystemId,
    this.hubSystemId,
    this.gateJumps = 0,
    this.wormholeJumps = 0,
    this.summary = '',
    this.alreadyInHub = false,
    this.found = false,
  });

  final int? approachSystemId;
  final int? hubSystemId;
  final int gateJumps;
  final int wormholeJumps;
  final String summary;
  final bool alreadyInHub;
  final bool found;
}

class ExplorationRouteEngine {
  /// Naive first-visit BFS that ignores wormhole risk and preferences.
  static RouteResult route(RouteRequest request, GraphSnapshot graph) {
    if (request.originSystemId == request.destinationSystemId) {
      return const RouteResult(
        outcome: RouteOutcome.found,
        gateJumps: 1,
        wormholeJumps: 0,
        maxRisk: EdgeRisk.caution,
      );
    }
    final adj = <int, List<DirectedExplorationEdge>>{};
    for (final edge in graph.edges) {
      adj.putIfAbsent(edge.fromSystemId, () => []).add(edge);
    }
    final seen = <int>{request.originSystemId};
    final queue = <(int, List<RouteStep>)>[
      (request.originSystemId, const <RouteStep>[]),
    ];
    while (queue.isNotEmpty) {
      final (node, path) = queue.removeAt(0);
      for (final edge in adj[node] ?? const <DirectedExplorationEdge>[]) {
        if (edge.kind != 'gate') continue;
        if (!seen.add(edge.toSystemId)) continue;
        final next = [
          ...path,
          RouteStep(
            fromSystemId: edge.fromSystemId,
            toSystemId: edge.toSystemId,
            edgeKey: edge.key,
            kind: edge.kind,
          ),
        ];
        if (edge.toSystemId == request.destinationSystemId) {
          return RouteResult(
            outcome: RouteOutcome.found,
            steps: next,
            gateJumps: next.length,
            wormholeJumps: 0,
            riskSum: 0,
          );
        }
        queue.add((edge.toSystemId, next));
      }
    }
    return const RouteResult(outcome: RouteOutcome.noRouteInGraph);
  }
}

class NearestEntranceFinder {
  static NearestEntranceOutcome find({
    required int originSystemId,
    required int hubSystemId,
    required GraphSnapshot graph,
    RoutePreferences preferences = RoutePreferences.defaults,
  }) {
    if (originSystemId == hubSystemId) {
      return const NearestEntranceOutcome(
        alreadyInHub: true,
        found: true,
        summary: 'Already in hub',
      );
    }
    final result = ExplorationRouteEngine.route(
      RouteRequest(
        originSystemId: originSystemId,
        destinationSystemId: hubSystemId,
        preferences: preferences,
      ),
      graph,
    );
    return NearestEntranceOutcome(
      found: result.outcome == RouteOutcome.found,
      approachSystemId: result.steps.isEmpty
          ? null
          : result.steps.last.fromSystemId,
      hubSystemId: hubSystemId,
      gateJumps: result.gateJumps,
      wormholeJumps: result.wormholeJumps,
      summary: '${result.gateJumps} jumps',
    );
  }
}

class PublicConnectionFilter {
  const PublicConnectionFilter({
    this.hubSystemId,
    this.farCategory,
    this.regionSubstring,
  });

  final int? hubSystemId;
  final SecurityCategory? farCategory;
  final String? regionSubstring;
}
