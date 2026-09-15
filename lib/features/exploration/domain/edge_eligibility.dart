import 'exploration_observation.dart';
import 'exploration_reference.dart';
import 'exploration_route.dart'
    hide ExplorationRouteEngine, NearestEntranceFinder;

/// Source, lifecycle, and preference exclusions plus disclosed risk rank.
class EdgeEligibility {
  const EdgeEligibility();

  static const _fiveMinutes = Duration(minutes: 5);
  static const _twentyFourHours = Duration(hours: 24);

  static EdgeAssessment assess({
    required DirectedExplorationEdge edge,
    required DateTime now,
    RoutePreferences preferences = RoutePreferences.defaults,
    DateTime? verifiedAt,
    DateTime? expiresAt,
    DateTime? publicValidatedAt,
    ConnectionLifecycle lifecycle = ConnectionLifecycle.active,
    bool listedInLatestSnapshot = true,
    bool applyUserAvoids = true,
  }) {
    final structural = _structuralReason(
      edge: edge,
      now: now,
      preferences: preferences,
      verifiedAt: verifiedAt,
      expiresAt: expiresAt,
      publicValidatedAt: publicValidatedAt,
      lifecycle: lifecycle,
      listedInLatestSnapshot: listedInLatestSnapshot,
    );
    if (structural != null) {
      return EdgeAssessment(
        edge: edge,
        eligible: false,
        reason: structural,
        risk: riskOf(edge),
      );
    }

    if (applyUserAvoids) {
      final preference = _preferenceReason(
        edge: edge,
        preferences: preferences,
      );
      if (preference != null) {
        return EdgeAssessment(
          edge: edge,
          eligible: false,
          reason: preference,
          risk: riskOf(edge),
        );
      }
    }

    return EdgeAssessment(edge: edge, eligible: true, risk: riskOf(edge));
  }

  static String? _structuralReason({
    required DirectedExplorationEdge edge,
    required DateTime now,
    required RoutePreferences preferences,
    required DateTime? verifiedAt,
    required DateTime? expiresAt,
    required DateTime? publicValidatedAt,
    required ConnectionLifecycle lifecycle,
    required bool listedInLatestSnapshot,
  }) {
    if (edge.fromSystemId == 0 ||
        edge.toSystemId == 0 ||
        edge.fromSystemId == edge.toSystemId) {
      return 'unresolved-endpoints';
    }
    if (lifecycle == ConnectionLifecycle.closed) return 'closed';
    if (lifecycle == ConnectionLifecycle.retired) return 'retired';
    if (!listedInLatestSnapshot) return 'omitted';
    if (expiresAt != null && !now.isBefore(expiresAt)) return 'expired';
    if (verifiedAt != null && now.difference(verifiedAt) >= _twentyFourHours) {
      return 'verification-expired';
    }
    if (publicValidatedAt != null) {
      final age = now.difference(publicValidatedAt);
      if (age >= _twentyFourHours) return 'public-view-only';
      if (age >= _fiveMinutes && !preferences.useStaleCachedConnections) {
        return 'stale';
      }
    }
    return null;
  }

  static String? _preferenceReason({
    required DirectedExplorationEdge edge,
    required RoutePreferences preferences,
  }) {
    if (preferences.avoidEol && edge.eol) return 'avoid-eol';
    if (preferences.avoidCriticalMass && edge.critical) return 'avoid-critical';
    final to = ExplorationSpace.categoryOf(edge.toSystemId);
    if (preferences.avoidLowsec && to == SecurityCategory.lowsec) {
      return 'avoid-lowsec';
    }
    if (preferences.avoidNullsec && to == SecurityCategory.nullsec) {
      return 'avoid-nullsec';
    }
    return null;
  }

  static int riskRank(DirectedExplorationEdge edge) {
    final to = ExplorationSpace.categoryOf(edge.toSystemId);
    var rank = 0;
    if (edge.kind == 'wormhole') rank = 1;
    if (to == SecurityCategory.unknown || to == SecurityCategory.special) {
      rank = rank < 1 ? 1 : rank;
    }
    if (to == SecurityCategory.lowsec ||
        to == SecurityCategory.nullsec ||
        edge.toSystemId == ExplorationSpace.pochvenSystemId) {
      rank = 2;
    }
    if (edge.eol || edge.critical) rank = 3;
    return rank;
  }

  static EdgeRisk riskOf(DirectedExplorationEdge edge) {
    return riskFromRank(riskRank(edge));
  }

  static EdgeRisk riskFromRank(int rank) {
    return switch (rank) {
      0 => EdgeRisk.lower,
      1 => EdgeRisk.caution,
      2 => EdgeRisk.high,
      _ => EdgeRisk.veryHigh,
    };
  }
}
