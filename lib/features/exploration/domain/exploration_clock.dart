/// Injectable UTC clock. Domain functions take [now] explicitly.
class ExplorationClock {
  ExplorationClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  DateTime now() => _now().toUtc();

  static DateTime get t0 => DateTime.utc(2026, 9, 15, 12);
}

enum FeedFreshness { fresh, stale, viewOnly }

enum TimeEstimate { stable, eol, expired, unknown }

class ExplorationTime {
  static const freshWindow = Duration(minutes: 5);
  static const viewOnlyWindow = Duration(hours: 24);
  static const eolHorizon = Duration(hours: 4);
  static const backoffSteps = [300, 600, 900];

  /// Inclusive 5m Fresh, exact 5m Stale, exact 24h view-only.
  static FeedFreshness feedFreshness({
    required DateTime validatedAt,
    required DateTime now,
  }) {
    final age = now.difference(validatedAt);
    if (age >= viewOnlyWindow) return FeedFreshness.viewOnly;
    if (age >= freshWindow) return FeedFreshness.stale;
    return FeedFreshness.fresh;
  }

  /// Exact 4h remaining is Stable; one millisecond less is EOL; at expiry
  /// the connection is expired, not Collapsed.
  static TimeEstimate timeEstimate({
    required DateTime expiresAt,
    required DateTime now,
  }) {
    final remaining = expiresAt.difference(now);
    if (remaining <= Duration.zero) return TimeEstimate.expired;
    if (remaining >= eolHorizon) return TimeEstimate.stable;
    return TimeEstimate.eol;
  }

  static Duration backoff(int failureCount) {
    if (failureCount <= 1) return Duration(seconds: backoffSteps[0]);
    if (failureCount == 2) return Duration(seconds: backoffSteps[1]);
    return Duration(seconds: backoffSteps[2]);
  }

  static DateTime retryAfter({
    required DateTime failedAt,
    int? retryAfterSeconds,
    int failureCount = 1,
  }) {
    final seconds = retryAfterSeconds ?? backoff(failureCount).inSeconds;
    return failedAt.add(Duration(seconds: seconds));
  }
}
