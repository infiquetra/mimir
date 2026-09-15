/// Naive X5 planner: misses the +1ms ticks and delays stale/view-only wakes.
class ExplorationDeadlinePlanner {
  const ExplorationDeadlinePlanner();

  static DateTime publicBecomesStale(DateTime validatedAt) =>
      validatedAt.add(const Duration(minutes: 5, milliseconds: 1));

  static DateTime publicBecomesViewOnly(DateTime validatedAt) =>
      validatedAt.add(const Duration(hours: 24, milliseconds: 1));

  static DateTime localVerificationExpires(DateTime verifiedAt) =>
      verifiedAt.add(const Duration(hours: 24, milliseconds: 1));

  static DateTime currentOriginStopsBeingCurrent(DateTime observedAt) =>
      observedAt.add(const Duration(seconds: 60));

  static DateTime stableBecomesEol(DateTime expiresAt) =>
      expiresAt.subtract(const Duration(hours: 4));

  static DateTime pastReportedExpiry(DateTime expiresAt) =>
      expiresAt.add(const Duration(milliseconds: 1));

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
      if (originObservedAt != null)
        currentOriginStopsBeingCurrent(originObservedAt),
      if (expiresAt != null) stableBecomesEol(expiresAt),
      if (expiresAt != null) pastReportedExpiry(expiresAt),
    ]..sort();
    return candidates.isEmpty ? null : candidates.first;
  }
}
