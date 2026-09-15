import 'exploration_observation.dart';
import 'exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;

/// Builds a directed multigraph from real gates plus eligible wormholes.
///
/// Gates use only actual source rows (no invented reverse). Wormholes emit
/// two directed edges with §4.4 endpoint orientation. Canonical keys are
/// insertion-order independent so `w01` precedes `w02` on equal cost.
class ExplorationGraphBuilder {
  const ExplorationGraphBuilder();

  /// Locale-independent canonical directed key tuple.
  static String canonicalTuple({
    required String sourceKind,
    required String sourceScope,
    required String sourceRecordKey,
    required int fromSystemId,
    required int toSystemId,
    required String direction,
  }) {
    return '$sourceKind|$sourceScope|$sourceRecordKey|'
        '$fromSystemId|$toSystemId|$direction';
  }

  static GraphSnapshot fromEdges(
    List<DirectedExplorationEdge> edges, {
    DateTime? capturedAt,
    bool topologyAvailable = true,
  }) {
    return GraphSnapshot(
      nodes: {
        for (final edge in edges) ...[edge.fromSystemId, edge.toSystemId],
      },
      edges: List<DirectedExplorationEdge>.from(edges),
      capturedAt: capturedAt,
      topologyAvailable: topologyAvailable,
    );
  }

  static GraphSnapshot build({
    List<DirectedExplorationEdge> gates = const [],
    List<PublicConnection> publicConnections = const [],
    List<LocalConnection> localConnections = const [],
    DateTime? capturedAt,
    bool topologyAvailable = true,
  }) {
    return fromEdges(
      [
        ...directedGates(gates),
        for (final connection in publicConnections) ...fromPublic(connection),
        for (final link in localConnections) ...fromLocal(link),
      ],
      capturedAt: capturedAt,
      topologyAvailable: topologyAvailable,
    );
  }

  /// Directed gates only. One-way rows do not gain an invented reverse.
  static List<DirectedExplorationEdge> directedGates(
    List<DirectedExplorationEdge> oneWay,
  ) {
    return List<DirectedExplorationEdge>.from(oneWay);
  }

  static List<DirectedExplorationEdge> fromPublic(PublicConnection connection) {
    if (connection.hub.systemId == 0 || connection.far.systemId == 0) {
      return const [];
    }
    if (connection.hub.systemId == connection.far.systemId) {
      return const [];
    }
    final recordKey = connection.providerKey;
    return [
      DirectedExplorationEdge(
        key: '$recordKey-fwd',
        fromSystemId: connection.hub.systemId,
        toSystemId: connection.far.systemId,
        kind: 'wormhole',
        canonicalKey: canonicalTuple(
          sourceKind: 'public',
          sourceScope: 'evescout',
          sourceRecordKey: recordKey,
          fromSystemId: connection.hub.systemId,
          toSystemId: connection.far.systemId,
          direction: 'fwd',
        ),
        fromTypeCode: connection.hub.typeCode,
        toTypeCode: connection.far.typeCode,
        fromSignature: connection.hub.signature,
        toSignature: connection.far.signature,
      ),
      DirectedExplorationEdge(
        key: '$recordKey-rev',
        fromSystemId: connection.far.systemId,
        toSystemId: connection.hub.systemId,
        kind: 'wormhole',
        canonicalKey: canonicalTuple(
          sourceKind: 'public',
          sourceScope: 'evescout',
          sourceRecordKey: recordKey,
          fromSystemId: connection.far.systemId,
          toSystemId: connection.hub.systemId,
          direction: 'rev',
        ),
        fromTypeCode: connection.far.typeCode,
        toTypeCode: connection.hub.typeCode,
        fromSignature: connection.far.signature,
        toSignature: connection.hub.signature,
      ),
    ];
  }

  /// Verified active local links become a directed pair. Unverified, closed,
  /// or retired links emit nothing. Observed K162 is preserved; never B274.
  static List<DirectedExplorationEdge> fromLocal(LocalConnection link) {
    if (link.verifiedAt == null) return const [];
    if (link.lifecycle != ConnectionLifecycle.active) return const [];
    if (link.fromSystemId == 0 ||
        link.toSystemId == 0 ||
        link.fromSystemId == link.toSystemId) {
      return const [];
    }
    final forward = link.forwardType();
    final reverse = link.reverseType();
    return [
      DirectedExplorationEdge(
        key: '${link.id}-fwd',
        fromSystemId: link.fromSystemId,
        toSystemId: link.toSystemId,
        kind: 'wormhole',
        privateOwner: link.characterId,
        canonicalKey: canonicalTuple(
          sourceKind: 'local',
          sourceScope: '${link.characterId}',
          sourceRecordKey: link.id,
          fromSystemId: link.fromSystemId,
          toSystemId: link.toSystemId,
          direction: 'fwd',
        ),
        fromTypeCode: forward,
        toTypeCode: reverse,
        fromSignature: link.fromSignature,
        toSignature: link.toSignature,
      ),
      DirectedExplorationEdge(
        key: '${link.id}-rev',
        fromSystemId: link.toSystemId,
        toSystemId: link.fromSystemId,
        kind: 'wormhole',
        privateOwner: link.characterId,
        canonicalKey: canonicalTuple(
          sourceKind: 'local',
          sourceScope: '${link.characterId}',
          sourceRecordKey: link.id,
          fromSystemId: link.toSystemId,
          toSystemId: link.fromSystemId,
          direction: 'rev',
        ),
        fromTypeCode: reverse,
        toTypeCode: forward,
        fromSignature: link.toSignature,
        toSignature: link.fromSignature,
      ),
    ];
  }
}
