/// Exact eligibility-boundary instants. 4h and 60s equalities need the +1ms tick.
class ExplorationDeadlinePlanner {
  const ExplorationDeadlinePlanner();

  static DateTime publicBecomesStale(DateTime validatedAt) =>
      validatedAt.add(const Duration(minutes: 5));

  static DateTime publicBecomesViewOnly(DateTime validatedAt) =>
      validatedAt.add(const Duration(hours: 24));

  static DateTime localVerificationExpires(DateTime verifiedAt) =>
      verifiedAt.add(const Duration(hours: 24));

  static DateTime currentOriginStopsBeingCurrent(DateTime observedAt) =>
      observedAt.add(const Duration(seconds: 60, milliseconds: 1));

  static DateTime stableBecomesEol(DateTime expiresAt) => expiresAt
      .subtract(const Duration(hours: 4))
      .add(const Duration(milliseconds: 1));

  static DateTime pastReportedExpiry(DateTime expiresAt) => expiresAt;

  /// Next graph/feed eligibility wake. Origin 60s freshness is a separate
  /// location tick via [currentOriginStopsBeingCurrent].
  static DateTime? earliest({
    DateTime? publicValidatedAt,
    DateTime? verifiedAt,
    DateTime? originObservedAt,
    DateTime? expiresAt,
  }) {
    final candidates = <DateTime>[
      if (publicValidatedAt != null) publicBecomesStale(publicValidatedAt),
      if (publicValidatedAt != null) publicBecomesViewOnly(publicValidatedAt),
      if (verifiedAt != null) localVerificationExpires(verifiedAt),
      if (expiresAt != null) stableBecomesEol(expiresAt),
      if (expiresAt != null) pastReportedExpiry(expiresAt),
    ]..sort();
    return candidates.isEmpty ? null : candidates.first;
  }
}
