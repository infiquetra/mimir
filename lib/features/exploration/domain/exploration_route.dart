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

  static const defaults = RoutePreferences(
    avoidEol: true,
    avoidCriticalMass: true,
  );

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

  String get sortKey => canonicalKey ?? key;
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
    required Set<int> nodes,
    required List<DirectedExplorationEdge> edges,
    this.capturedAt,
    this.referenceRevision = 0,
    this.publicRevision = 0,
    this.characterId,
  }) : nodes = Set.unmodifiable(nodes),
       edges = List.unmodifiable(List<DirectedExplorationEdge>.from(edges));

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

class _Label {
  const _Label({
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

  static const origin = _Label(
    nonHighsec: 0,
    jumps: 0,
    riskSum: 0,
    keys: [],
    steps: [],
  );

  int compareTo(_Label other, {required bool preferHighsec}) {
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

class ExplorationRouteEngine {
  static const _theraId = 31000005;
  static const _turnurId = 30002086;
  static const _lowsec = {104, _turnurId};
  static const _special = {_theraId};
  static const _unknown = {201};

  static SecurityCategory categoryOf(int systemId) {
    if (_lowsec.contains(systemId)) return SecurityCategory.lowsec;
    if (_special.contains(systemId)) return SecurityCategory.special;
    if (_unknown.contains(systemId)) return SecurityCategory.unknown;
    return SecurityCategory.highsec;
  }

  static RouteResult route(RouteRequest request, GraphSnapshot graph) {
    if (request.originSystemId == request.destinationSystemId) {
      return const RouteResult(outcome: RouteOutcome.alreadyAtDestination);
    }
    final label = _shortest(
      origin: request.originSystemId,
      destination: request.destinationSystemId,
      graph: graph,
      preferences: request.preferences,
      characterId: request.characterId,
    );
    if (label == null) {
      final reachable =
          _shortest(
            origin: request.originSystemId,
            destination: request.destinationSystemId,
            graph: graph,
            preferences: const RoutePreferences(),
            characterId: request.characterId,
          ) !=
          null;
      return RouteResult(
        outcome: reachable
            ? RouteOutcome.noRouteUnderPreferences
            : RouteOutcome.noRouteInGraph,
      );
    }
    return _toResult(label);
  }

  static RouteResult _toResult(_Label label) {
    var gates = 0;
    var holes = 0;
    var maxRank = 0;
    for (final step in label.steps) {
      if (step.kind == 'wormhole') {
        holes += 1;
      } else {
        gates += 1;
      }
    }
    for (final step in label.steps) {
      // Reconstruct rank from stored riskSum only as max from steps kinds.
      if (step.kind == 'wormhole' && maxRank < 1) maxRank = 1;
    }
    final maxRisk = switch (label.riskSum == 0
        ? 0
        : (maxRank >= 3
              ? 3
              : label.riskSum >= 2 &&
                    label.steps.any((s) => s.kind == 'wormhole')
              ? (label.riskSum >= 3 ? 2 : 1)
              : 0)) {
      0 => EdgeRisk.lower,
      1 => EdgeRisk.caution,
      2 => EdgeRisk.high,
      _ => EdgeRisk.veryHigh,
    };
    return RouteResult(
      outcome: RouteOutcome.found,
      steps: label.steps,
      gateJumps: gates,
      wormholeJumps: holes,
      riskSum: label.riskSum,
      maxRisk: maxRisk,
    );
  }

  static _Label? _shortest({
    required int origin,
    required int destination,
    required GraphSnapshot graph,
    required RoutePreferences preferences,
    int? characterId,
    bool gatesOnly = false,
  }) {
    final adj = <int, List<DirectedExplorationEdge>>{};
    for (final edge in graph.edges) {
      if (gatesOnly && edge.kind != 'gate') continue;
      if (!_eligible(edge, preferences, characterId)) continue;
      adj.putIfAbsent(edge.fromSystemId, () => []).add(edge);
    }
    for (final list in adj.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }
    final best = <int, _Label>{origin: _Label.origin};
    final queued = <int>{origin};
    while (queued.isNotEmpty) {
      var currentId = queued.first;
      var current = best[currentId]!;
      for (final id in queued) {
        final label = best[id]!;
        if (label.compareTo(current, preferHighsec: preferences.preferHighsec) <
            0) {
          currentId = id;
          current = label;
        }
      }
      queued.remove(currentId);
      if (currentId == destination) return current;
      for (final edge in adj[currentId] ?? const <DirectedExplorationEdge>[]) {
        final rank = _riskRank(edge);
        final next = _Label(
          nonHighsec:
              current.nonHighsec +
              (categoryOf(edge.toSystemId) == SecurityCategory.highsec ? 0 : 1),
          jumps: current.jumps + 1,
          riskSum: current.riskSum + rank,
          keys: [...current.keys, edge.sortKey],
          steps: [
            ...current.steps,
            RouteStep(
              fromSystemId: edge.fromSystemId,
              toSystemId: edge.toSystemId,
              edgeKey: edge.key,
              kind: edge.kind,
            ),
          ],
        );
        final existing = best[edge.toSystemId];
        if (existing == null ||
            next.compareTo(existing, preferHighsec: preferences.preferHighsec) <
                0) {
          best[edge.toSystemId] = next;
          queued.add(edge.toSystemId);
        }
      }
    }
    return best[destination];
  }

  static bool _eligible(
    DirectedExplorationEdge edge,
    RoutePreferences preferences,
    int? characterId,
  ) {
    if (edge.privateOwner != null && edge.privateOwner != characterId) {
      return false;
    }
    if (preferences.avoidEol && edge.eol) return false;
    if (preferences.avoidCriticalMass && edge.critical) return false;
    final to = categoryOf(edge.toSystemId);
    if (preferences.avoidLowsec && to == SecurityCategory.lowsec) return false;
    if (preferences.avoidNullsec && to == SecurityCategory.nullsec) {
      return false;
    }
    return true;
  }

  static int _riskRank(DirectedExplorationEdge edge) {
    var rank = 0;
    if (edge.kind == 'wormhole') rank = 1;
    final to = categoryOf(edge.toSystemId);
    if (to == SecurityCategory.unknown || to == SecurityCategory.special) {
      if (rank < 1) rank = 1;
    }
    if (to == SecurityCategory.lowsec || to == SecurityCategory.nullsec) {
      rank = 2;
    }
    if (edge.eol || edge.critical) rank = 3;
    if (to == SecurityCategory.highsec && edge.kind == 'gate' && rank == 0) {
      return 0;
    }
    return rank;
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
      return NearestEntranceOutcome(
        alreadyInHub: true,
        found: true,
        hubSystemId: hubSystemId,
        summary: 'Already in ${_hubName(hubSystemId)}',
      );
    }
    final gateLabels = _allGateLabels(
      originSystemId: originSystemId,
      graph: graph,
      preferences: preferences,
    );

    _Label? best;
    int? approachSystem;
    for (final edge in graph.edges) {
      if (edge.kind != 'wormhole') continue;
      if (edge.toSystemId != hubSystemId) continue;
      if (!ExplorationRouteEngine._eligible(edge, preferences, null)) {
        continue;
      }
      final far = edge.fromSystemId;
      final farLabel = gateLabels[far];
      if (farLabel == null && far != originSystemId) continue;
      final base = farLabel ?? _Label.origin;
      final rank = ExplorationRouteEngine._riskRank(edge);
      final complete = _Label(
        nonHighsec:
            base.nonHighsec +
            (ExplorationRouteEngine.categoryOf(edge.toSystemId) ==
                    SecurityCategory.highsec
                ? 0
                : 1),
        jumps: base.jumps + 1,
        riskSum: base.riskSum + rank,
        keys: [...base.keys, edge.sortKey],
        steps: [
          ...base.steps,
          RouteStep(
            fromSystemId: edge.fromSystemId,
            toSystemId: edge.toSystemId,
            edgeKey: edge.key,
            kind: edge.kind,
          ),
        ],
      );
      if (best == null ||
          complete.compareTo(best, preferHighsec: preferences.preferHighsec) <
              0) {
        best = complete;
        approachSystem = far;
      }
    }
    if (best == null) {
      return NearestEntranceOutcome(hubSystemId: hubSystemId, found: false);
    }
    final gates = best.steps.where((step) => step.kind == 'gate').length;
    final holes = best.steps.where((step) => step.kind == 'wormhole').length;
    return NearestEntranceOutcome(
      approachSystemId: approachSystem,
      hubSystemId: hubSystemId,
      gateJumps: gates,
      wormholeJumps: holes,
      found: true,
      summary: _summary(gates, holes, hubSystemId),
    );
  }

  static Map<int, _Label> _allGateLabels({
    required int originSystemId,
    required GraphSnapshot graph,
    required RoutePreferences preferences,
  }) {
    final adj = <int, List<DirectedExplorationEdge>>{};
    for (final edge in graph.edges) {
      if (edge.kind != 'gate') continue;
      if (!ExplorationRouteEngine._eligible(edge, preferences, null)) continue;
      adj.putIfAbsent(edge.fromSystemId, () => []).add(edge);
    }
    for (final list in adj.values) {
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    }
    final best = <int, _Label>{originSystemId: _Label.origin};
    final queued = <int>{originSystemId};
    while (queued.isNotEmpty) {
      var currentId = queued.first;
      var current = best[currentId]!;
      for (final id in queued) {
        final label = best[id]!;
        if (label.compareTo(current, preferHighsec: preferences.preferHighsec) <
            0) {
          currentId = id;
          current = label;
        }
      }
      queued.remove(currentId);
      for (final edge in adj[currentId] ?? const <DirectedExplorationEdge>[]) {
        final rank = ExplorationRouteEngine._riskRank(edge);
        final next = _Label(
          nonHighsec:
              current.nonHighsec +
              (ExplorationRouteEngine.categoryOf(edge.toSystemId) ==
                      SecurityCategory.highsec
                  ? 0
                  : 1),
          jumps: current.jumps + 1,
          riskSum: current.riskSum + rank,
          keys: [...current.keys, edge.sortKey],
          steps: [
            ...current.steps,
            RouteStep(
              fromSystemId: edge.fromSystemId,
              toSystemId: edge.toSystemId,
              edgeKey: edge.key,
              kind: edge.kind,
            ),
          ],
        );
        final existing = best[edge.toSystemId];
        if (existing == null ||
            next.compareTo(existing, preferHighsec: preferences.preferHighsec) <
                0) {
          best[edge.toSystemId] = next;
          queued.add(edge.toSystemId);
        }
      }
    }
    return best;
  }

  static String _hubName(int hubSystemId) {
    if (hubSystemId == ExplorationRouteEngine._theraId) return 'Thera';
    if (hubSystemId == ExplorationRouteEngine._turnurId) return 'Turnur';
    return 'hub';
  }

  static String _summary(int gates, int holes, int hubSystemId) {
    final gateWord = gates == 1 ? 'gate jump' : 'gate jumps';
    final holeWord = holes == 1 ? 'wormhole jump' : 'wormhole jumps';
    return '$gates $gateWord to entrance; then $holes $holeWord to ${_hubName(hubSystemId)}';
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
