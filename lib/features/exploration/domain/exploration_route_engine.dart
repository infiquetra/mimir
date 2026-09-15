import 'package:collection/collection.dart';

import '../../../core/logging/logger.dart';
import 'edge_eligibility.dart';
import 'exploration_reference.dart';
import 'exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;

/// Tuple-cost Dijkstra for Shortest and Prefer Highsec.
///
/// Diagnostic connectivity never returns a preference-relaxed path as a route.
class ExplorationRouteEngine {
  static const _log = 'EXPLORATION.ROUTE';

  static SecurityCategory categoryOf(int systemId) =>
      ExplorationSpace.categoryOf(systemId);

  static int riskRank(DirectedExplorationEdge edge) =>
      EdgeEligibility.riskRank(edge);

  static RouteResult route(RouteRequest request, GraphSnapshot graph) {
    if (request.originSystemId == request.destinationSystemId) {
      Log.i(_log, 'already at destination ${request.originSystemId}');
      return const RouteResult(outcome: RouteOutcome.alreadyAtDestination);
    }
    if (!graph.topologyAvailable) {
      Log.w(_log, 'topology unavailable for ${request.operationId}');
      return const RouteResult(outcome: RouteOutcome.dataUnavailable);
    }

    final found = shortestLabel(
      origin: request.originSystemId,
      destination: request.destinationSystemId,
      graph: graph,
      preferences: request.preferences,
      characterId: request.characterId,
    );
    if (found != null) {
      final result = toResult(found);
      Log.i(
        _log,
        'found ${request.originSystemId}->${request.destinationSystemId} '
        'jumps=${result.totalJumps} gates=${result.gateJumps} '
        'wh=${result.wormholeJumps} riskSum=${result.riskSum}',
      );
      return result;
    }

    final reachableWithoutAvoids =
        shortestLabel(
          origin: request.originSystemId,
          destination: request.destinationSystemId,
          graph: graph,
          preferences: request.preferences,
          characterId: request.characterId,
          applyUserAvoids: false,
        ) !=
        null;
    final outcome = reachableWithoutAvoids
        ? RouteOutcome.noRouteUnderPreferences
        : RouteOutcome.noRouteInGraph;
    Log.i(
      _log,
      'no route ${request.originSystemId}->${request.destinationSystemId} '
      'outcome=$outcome',
    );
    return RouteResult(outcome: outcome);
  }

  static RouteResult toResult(RouteCostLabel label) {
    var gates = 0;
    var holes = 0;
    var maxRank = 0;
    for (final step in label.steps) {
      if (step.kind == 'wormhole') {
        holes += 1;
      } else {
        gates += 1;
      }
      final rank = switch (step.risk) {
        EdgeRisk.lower => 0,
        EdgeRisk.caution => 1,
        EdgeRisk.high => 2,
        EdgeRisk.veryHigh => 3,
      };
      if (rank > maxRank) maxRank = rank;
    }
    return RouteResult(
      outcome: RouteOutcome.found,
      steps: label.steps,
      gateJumps: gates,
      wormholeJumps: holes,
      riskSum: label.riskSum,
      maxRisk: EdgeEligibility.riskFromRank(maxRank),
    );
  }

  static RouteCostLabel? shortestLabel({
    required int origin,
    required int destination,
    required GraphSnapshot graph,
    required RoutePreferences preferences,
    int? characterId,
    bool gatesOnly = false,
    bool applyUserAvoids = true,
  }) {
    final best = dijkstra(
      origin: origin,
      graph: graph,
      preferences: preferences,
      characterId: characterId,
      gatesOnly: gatesOnly,
      applyUserAvoids: applyUserAvoids,
      stopAt: destination,
    );
    return best[destination];
  }

  static Map<int, RouteCostLabel> dijkstra({
    required int origin,
    required GraphSnapshot graph,
    required RoutePreferences preferences,
    int? characterId,
    bool gatesOnly = false,
    bool applyUserAvoids = true,
    int? stopAt,
  }) {
    final adj = <int, List<DirectedExplorationEdge>>{};
    for (final edge in graph.edges) {
      if (gatesOnly && edge.kind != 'gate') continue;
      if (!isEligible(
        edge: edge,
        preferences: preferences,
        characterId: characterId,
        applyUserAvoids: applyUserAvoids,
      )) {
        continue;
      }
      adj.putIfAbsent(edge.fromSystemId, () => []).add(edge);
    }
    for (final list in adj.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }

    final preferHighsec = preferences.preferHighsec;
    final best = <int, RouteCostLabel>{origin: RouteCostLabel.origin};
    final queue = HeapPriorityQueue<_Queued>((a, b) {
      final cmp = a.label.compareTo(b.label, preferHighsec: preferHighsec);
      if (cmp != 0) return cmp;
      return a.node.compareTo(b.node);
    });
    queue.add(_Queued(origin, RouteCostLabel.origin));

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final held = best[current.node];
      if (held == null ||
          current.label.compareTo(held, preferHighsec: preferHighsec) > 0) {
        continue;
      }
      if (stopAt != null && current.node == stopAt) {
        return best;
      }
      for (final edge
          in adj[current.node] ?? const <DirectedExplorationEdge>[]) {
        final next = current.label.extend(edge);
        final existing = best[edge.toSystemId];
        if (existing == null ||
            next.compareTo(existing, preferHighsec: preferHighsec) < 0) {
          best[edge.toSystemId] = next;
          queue.add(_Queued(edge.toSystemId, next));
        }
      }
    }
    return best;
  }

  static bool isEligible({
    required DirectedExplorationEdge edge,
    required RoutePreferences preferences,
    int? characterId,
    bool applyUserAvoids = true,
  }) {
    if (edge.privateOwner != null && edge.privateOwner != characterId) {
      return false;
    }
    return EdgeEligibility.assess(
      edge: edge,
      now: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      preferences: preferences,
      applyUserAvoids: applyUserAvoids,
    ).eligible;
  }
}

class RouteCostLabel {
  const RouteCostLabel({
    required this.nonHighsec,
    required this.jumps,
    required this.riskSum,
    required this.keys,
    required this.steps,
  });

  final int nonHighsec;
  final int jumps;
  final int riskSum;
  final List<String> keys;
  final List<RouteStep> steps;

  static const origin = RouteCostLabel(
    nonHighsec: 0,
    jumps: 0,
    riskSum: 0,
    keys: [],
    steps: [],
  );

  RouteCostLabel extend(DirectedExplorationEdge edge) {
    final rank = EdgeEligibility.riskRank(edge);
    final toHighsec =
        ExplorationSpace.categoryOf(edge.toSystemId) ==
        SecurityCategory.highsec;
    return RouteCostLabel(
      nonHighsec: nonHighsec + (toHighsec ? 0 : 1),
      jumps: jumps + 1,
      riskSum: riskSum + rank,
      keys: [...keys, edge.sortKey],
      steps: [
        ...steps,
        RouteStep(
          fromSystemId: edge.fromSystemId,
          toSystemId: edge.toSystemId,
          edgeKey: edge.key,
          kind: edge.kind,
          fromSignature: edge.fromSignature,
          toSignature: edge.toSignature,
          fromTypeCode: edge.fromTypeCode ?? '',
          toTypeCode: edge.toTypeCode ?? '',
          risk: EdgeEligibility.riskFromRank(rank),
        ),
      ],
    );
  }

  int compareTo(RouteCostLabel other, {required bool preferHighsec}) {
    if (preferHighsec) {
      final high = nonHighsec.compareTo(other.nonHighsec);
      if (high != 0) return high;
    }
    final jump = jumps.compareTo(other.jumps);
    if (jump != 0) return jump;
    final risk = riskSum.compareTo(other.riskSum);
    if (risk != 0) return risk;
    final limit = keys.length < other.keys.length
        ? keys.length
        : other.keys.length;
    for (var i = 0; i < limit; i++) {
      final key = keys[i].compareTo(other.keys[i]);
      if (key != 0) return key;
    }
    return keys.length.compareTo(other.keys.length);
  }
}

class _Queued {
  const _Queued(this.node, this.label);
  final int node;
  final RouteCostLabel label;
}
