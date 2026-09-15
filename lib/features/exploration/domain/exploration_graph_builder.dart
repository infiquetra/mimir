import 'exploration_observation.dart';
import 'exploration_route.dart';

/// Naive X5 builder: invents reverse gates, emits unverified locals, and
/// invents a B274 reverse for observed K162.
class ExplorationGraphBuilder {
  const ExplorationGraphBuilder();

  static GraphSnapshot fromEdges(
    List<DirectedExplorationEdge> edges, {
    DateTime? capturedAt,
    bool topologyAvailable = true,
  }) {
    return GraphSnapshot(
      nodes: {
        for (final edge in edges) ...[edge.fromSystemId, edge.toSystemId],
      },
      edges: [
        for (var i = 0; i < edges.length; i++)
          DirectedExplorationEdge(
            key: edges[i].key,
            fromSystemId: edges[i].fromSystemId,
            toSystemId: edges[i].toSystemId,
            kind: edges[i].kind,
            eol: edges[i].eol,
            critical: edges[i].critical,
            privateOwner: edges[i].privateOwner,
            canonicalKey: '${i.toString().padLeft(4, '0')}-${edges[i].sortKey}',
          ),
      ],
      capturedAt: capturedAt,
      topologyAvailable: topologyAvailable,
    );
  }

  static List<DirectedExplorationEdge> directedGates(
    List<DirectedExplorationEdge> oneWay,
  ) {
    return [
      for (final edge in oneWay) ...[
        edge,
        DirectedExplorationEdge(
          key: '${edge.key}-rev',
          fromSystemId: edge.toSystemId,
          toSystemId: edge.fromSystemId,
          kind: 'gate',
          canonicalKey: '${edge.sortKey}-rev',
        ),
      ],
    ];
  }

  static List<DirectedExplorationEdge> fromLocal(LocalConnection link) {
    return [
      DirectedExplorationEdge(
        key: '${link.id}-fwd',
        fromSystemId: link.fromSystemId,
        toSystemId: link.toSystemId,
        kind: 'wormhole',
        canonicalKey: link.id,
      ),
      DirectedExplorationEdge(
        key: '${link.id}-rev',
        fromSystemId: link.toSystemId,
        toSystemId: link.fromSystemId,
        kind: 'wormhole',
        canonicalKey: '${link.id}-rev',
      ),
    ];
  }
}
