import 'exploration_reference.dart';

export 'exploration_route_engine.dart';
export 'nearest_entrance_finder.dart';

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
    this.fromTypeCode,
    this.toTypeCode,
    this.fromSignature,
    this.toSignature,
  });

  final String key;
  final int fromSystemId;
  final int toSystemId;
  final String kind;
  final bool eol;
  final bool critical;
  final int? privateOwner;
  final String? canonicalKey;
  final String? fromTypeCode;
  final String? toTypeCode;
  final String? fromSignature;
  final String? toSignature;

  String get sortKey => canonicalKey ?? key;
}

/// Fixture and live-graph security categories used by eligibility and routing.
class ExplorationSpace {
  static const theraSystemId = 31000005;
  static const turnurSystemId = 30002086;
  static const pochvenSystemId = 10000070;

  static const _lowsec = {104, turnurSystemId};
  static const _special = {theraSystemId};
  static const _unknown = {201};
  static const _pochven = {pochvenSystemId};

  static SecurityCategory categoryOf(int systemId) {
    if (_lowsec.contains(systemId)) return SecurityCategory.lowsec;
    if (_pochven.contains(systemId)) return SecurityCategory.special;
    if (_special.contains(systemId)) return SecurityCategory.special;
    if (_unknown.contains(systemId)) return SecurityCategory.unknown;
    return SecurityCategory.highsec;
  }

  static String hubName(int systemId) {
    if (systemId == theraSystemId) return 'Thera';
    if (systemId == turnurSystemId) return 'Turnur';
    return 'hub';
  }
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
    this.topologyAvailable = true,
  }) : nodes = Set.unmodifiable(Set.of(nodes)),
       edges = List.unmodifiable(List<DirectedExplorationEdge>.from(edges));

  final Set<int> nodes;
  final List<DirectedExplorationEdge> edges;
  final DateTime? capturedAt;
  final int referenceRevision;
  final int publicRevision;
  final int? characterId;
  final bool topologyAvailable;
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
    this.fromSignature,
    this.toSignature,
    this.fromTypeCode,
    this.toTypeCode,
    this.risk = EdgeRisk.lower,
  });

  final int fromSystemId;
  final int toSystemId;
  final String edgeKey;
  final String kind;
  final String? fromSignature;
  final String? toSignature;
  final String? fromTypeCode;
  final String? toTypeCode;
  final EdgeRisk risk;
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
