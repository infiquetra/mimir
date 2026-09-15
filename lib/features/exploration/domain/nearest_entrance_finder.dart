import 'exploration_route.dart' hide ExplorationRouteEngine, NearestEntranceFinder;
import 'exploration_route_engine.dart';

/// Naive X5 nearest search: mixed-graph hops, no entry-edge preference check,
/// isolated origins reported as distance 0.
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
    if (result.outcome != RouteOutcome.found) {
      if (graph.nodes.contains(originSystemId) &&
          !graph.edges.any(
            (edge) =>
                edge.kind == 'gate' && edge.fromSystemId == originSystemId,
          )) {
        return NearestEntranceOutcome(
          found: true,
          approachSystemId: originSystemId,
          hubSystemId: hubSystemId,
          gateJumps: 0,
          wormholeJumps: 0,
          summary: '0 jumps',
        );
      }
      return NearestEntranceOutcome(hubSystemId: hubSystemId, found: false);
    }
    return NearestEntranceOutcome(
      found: true,
      approachSystemId: result.steps.isEmpty
          ? originSystemId
          : result.steps.last.fromSystemId,
      hubSystemId: hubSystemId,
      gateJumps: result.gateJumps,
      wormholeJumps: result.wormholeJumps,
      summary: '${result.gateJumps} jumps',
    );
  }
}
