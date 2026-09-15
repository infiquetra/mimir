import 'exploration_observation.dart';
import 'exploration_route.dart';

/// Naive X5 eligibility: almost everything stays eligible, including closed
/// and expired edges when stale opt-in is on.
class EdgeEligibility {
  const EdgeEligibility();

  static EdgeAssessment assess({
    required DirectedExplorationEdge edge,
    required DateTime now,
    RoutePreferences preferences = RoutePreferences.defaults,
    DateTime? verifiedAt,
    DateTime? expiresAt,
    DateTime? publicValidatedAt,
    ConnectionLifecycle lifecycle = ConnectionLifecycle.active,
    bool listedInLatestSnapshot = true,
  }) {
    if (edge.privateOwner != null &&
        preferences.useStaleCachedConnections == false &&
        edge.privateOwner == 0) {
      return EdgeAssessment(
        edge: edge,
        eligible: false,
        reason: 'wrong character',
      );
    }
    if (lifecycle == ConnectionLifecycle.retired &&
        !preferences.useStaleCachedConnections) {
      return EdgeAssessment(edge: edge, eligible: false, reason: 'retired');
    }
    return EdgeAssessment(edge: edge, eligible: true, risk: EdgeRisk.lower);
  }
}
