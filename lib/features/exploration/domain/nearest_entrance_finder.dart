import '../../../core/logging/logger.dart';
import 'exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;
import 'exploration_route_engine.dart';

/// Gate-only approach from origin, then append the far→hub wormhole entry.
class NearestEntranceFinder {
  static const _log = 'EXPLORATION.ROUTE';

  static NearestEntranceOutcome find({
    required int originSystemId,
    required int hubSystemId,
    required GraphSnapshot graph,
    RoutePreferences preferences = RoutePreferences.defaults,
  }) {
    if (originSystemId == hubSystemId) {
      final summary = 'Already in ${ExplorationSpace.hubName(hubSystemId)}';
      Log.i(_log, summary);
      return NearestEntranceOutcome(
        alreadyInHub: true,
        found: true,
        hubSystemId: hubSystemId,
        summary: summary,
      );
    }

    final hasOutgoingGate = graph.edges.any(
      (edge) => edge.kind == 'gate' && edge.fromSystemId == originSystemId,
    );
    if (!hasOutgoingGate) {
      Log.i(_log, 'isolated origin $originSystemId for hub $hubSystemId');
      return NearestEntranceOutcome(
        hubSystemId: hubSystemId,
        found: false,
        gateJumps: -1,
        summary:
            'Isolated origin; gate-only approach unavailable. '
            'Use Route Planner for private links.',
      );
    }

    final gateLabels = ExplorationRouteEngine.dijkstra(
      origin: originSystemId,
      graph: graph,
      preferences: preferences,
      gatesOnly: true,
    );

    RouteCostLabel? best;
    int? approachSystem;
    for (final edge in graph.edges) {
      if (edge.kind != 'wormhole') continue;
      if (edge.toSystemId != hubSystemId) continue;
      if (!ExplorationRouteEngine.isEligible(
        edge: edge,
        preferences: preferences,
      )) {
        continue;
      }
      final far = edge.fromSystemId;
      final farLabel = gateLabels[far];
      if (farLabel == null && far != originSystemId) continue;
      final complete = (farLabel ?? RouteCostLabel.origin).extend(edge);
      if (best == null ||
          complete.compareTo(best, preferHighsec: preferences.preferHighsec) <
              0) {
        best = complete;
        approachSystem = far;
      }
    }

    if (best == null) {
      Log.i(_log, 'no entrance to $hubSystemId from $originSystemId');
      return NearestEntranceOutcome(hubSystemId: hubSystemId, found: false);
    }

    final gates = best.steps.where((step) => step.kind == 'gate').length;
    final holes = best.steps.where((step) => step.kind == 'wormhole').length;
    final summary = _summary(gates, holes, hubSystemId);
    Log.i(_log, 'nearest $originSystemId -> $hubSystemId $summary');
    return NearestEntranceOutcome(
      approachSystemId: approachSystem,
      hubSystemId: hubSystemId,
      gateJumps: gates,
      wormholeJumps: holes,
      found: true,
      summary: summary,
    );
  }

  static String _summary(int gates, int holes, int hubSystemId) {
    final gateWord = gates == 1 ? 'gate jump' : 'gate jumps';
    final holeWord = holes == 1 ? 'wormhole jump' : 'wormhole jumps';
    return '$gates $gateWord to entrance; then $holes $holeWord to '
        '${ExplorationSpace.hubName(hubSystemId)}';
  }
}
