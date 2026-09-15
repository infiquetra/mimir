import 'exploration_reference.dart';
import 'exploration_route.dart';

/// Naive X5 solver: first-visit hop BFS on gates only, no preference tuple,
/// diagnostic path returned when avoids would have blocked a wormhole route.
class ExplorationRouteEngine {
  static RouteResult route(RouteRequest request, GraphSnapshot graph) {
    if (request.originSystemId == request.destinationSystemId) {
      return RouteResult(
        outcome: RouteOutcome.found,
        gateJumps: 1,
        wormholeJumps: 0,
        maxRisk: EdgeRisk.caution,
        steps: [
          RouteStep(
            fromSystemId: request.originSystemId,
            toSystemId: request.destinationSystemId,
            edgeKey: 'self',
          ),
        ],
      );
    }
    final adj = <int, List<DirectedExplorationEdge>>{};
    for (final edge in graph.edges) {
      if (edge.kind != 'gate') continue;
      adj.putIfAbsent(edge.fromSystemId, () => []).add(edge);
    }
    final seen = <int>{request.originSystemId};
    final queue = <(int, List<RouteStep>)>[
      (request.originSystemId, const <RouteStep>[]),
    ];
    while (queue.isNotEmpty) {
      final (node, path) = queue.removeAt(0);
      for (final edge in adj[node] ?? const <DirectedExplorationEdge>[]) {
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
            maxRisk: EdgeRisk.lower,
          );
        }
        queue.add((edge.toSystemId, next));
      }
    }
    if (!graph.topologyAvailable) {
      return const RouteResult(outcome: RouteOutcome.noRouteInGraph);
    }
    return const RouteResult(outcome: RouteOutcome.noRouteInGraph);
  }

  static SecurityCategory categoryOf(int systemId) {
    if (systemId == 104 || systemId == 30002086) {
      return SecurityCategory.lowsec;
    }
    return SecurityCategory.highsec;
  }
}
