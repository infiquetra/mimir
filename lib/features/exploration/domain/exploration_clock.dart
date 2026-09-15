/// Injectable UTC clock. Naive implementations may still call [DateTime.now].
class ExplorationClock {
  ExplorationClock({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  DateTime now() => _now();

  static DateTime get t0 => DateTime.utc(2026, 9, 15, 12);
}

/// Naive freshness: exclusive thresholds, so exact 5m/24h stay Fresh.
enum FeedFreshness { fresh, stale, viewOnly }

class ExplorationTime {
  static FeedFreshness feedFreshness({
    required DateTime validatedAt,
    required DateTime now,
  }) {
    final age = now.difference(validatedAt);
    if (age.inHours > 24) return FeedFreshness.viewOnly;
    if (age.inMinutes > 5) return FeedFreshness.stale;
    return FeedFreshness.fresh;
  }

  /// Naive: remaining_hours-style whole hours, so 4h+1ms stays Stable.
  static TimeEstimate timeEstimate({
    required DateTime expiresAt,
    required DateTime now,
  }) {
    final remaining = expiresAt.difference(now);
    if (remaining.isNegative || remaining == Duration.zero) {
      return TimeEstimate.expired;
    }
    if (remaining.inHours >= 4) return TimeEstimate.stable;
    return TimeEstimate.eol;
  }

  static Duration backoff(int failureCount) {
    return Duration(seconds: 60 * failureCount);
  }

  static DateTime retryAfter({
    required DateTime failedAt,
    int? retryAfterSeconds,
    int failureCount = 1,
  }) {
    final seconds = retryAfterSeconds ?? backoff(failureCount).inSeconds;
    if (seconds > 300) {
      return failedAt.add(const Duration(seconds: 300));
    }
    return failedAt.add(Duration(seconds: seconds));
  }
}

enum TimeEstimate { stable, eol, expired, unknown }
