enum RefreshOutcome {
  renewed,
  notModifiedRenewedAll,
  locked,
  incomplete,
  failed,
}

class SourceTimes {
  const SourceTimes({
    this.payloadReceivedAt,
    this.validatedAt,
    this.upstreamDate,
    this.lastModified,
    this.ageSeconds,
  });

  final DateTime? payloadReceivedAt;
  final DateTime? validatedAt;
  final DateTime? upstreamDate;
  final DateTime? lastModified;
  final int? ageSeconds;
}

class PageEvidence {
  const PageEvidence({
    this.page = 1,
    this.xPages,
    this.statusCode = 200,
    this.lastModified,
  });

  final int page;
  final int? xPages;
  final int statusCode;
  final DateTime? lastModified;
}

class HistoryCoverage {
  const HistoryCoverage({
    this.complete = true,
    this.rowCount = 0,
    this.termination,
  });

  final bool complete;
  final int rowCount;
  final String? termination;
}

class SnapshotEnvelope<T> {
  const SnapshotEnvelope({
    required this.payload,
    this.times = const SourceTimes(),
    this.pages = const [],
    this.coverage,
    this.complete = true,
  });

  final T payload;
  final SourceTimes times;
  final List<PageEvidence> pages;
  final HistoryCoverage? coverage;
  final bool complete;
}

/// Freshness, lease, and 304 coverage. Equality at the lease end locks.
class SnapshotFreshness {
  const SnapshotFreshness();

  /// RFC-style remaining lifetime from Date, Age, and max-age.
  ///
  /// F6: Date = T0−120s, Age = 120, max-age = 3600 → deadline 12:58.
  DateTime deadline({
    required DateTime receivedAt,
    DateTime? dateHeader,
    int? ageSeconds,
    int maxAgeSeconds = 3600,
  }) {
    var apparentAge = 0;
    if (dateHeader != null) {
      final delta = receivedAt.difference(dateHeader).inSeconds;
      if (delta > 0) apparentAge = delta;
    }
    final headerAge = ageSeconds ?? 0;
    final correctedAge = apparentAge > headerAge ? apparentAge : headerAge;
    final remaining = maxAgeSeconds - correctedAge;
    return receivedAt.add(Duration(seconds: remaining > 0 ? remaining : 0));
  }

  /// `now < leaseEndsAt`. Equality locks.
  bool offlineReadAllowed({
    required DateTime now,
    required DateTime leaseEndsAt,
  }) {
    return now.isBefore(leaseEndsAt);
  }

  RefreshOutcome applyNotModified({required bool pageOneOnly}) {
    if (pageOneOnly) return RefreshOutcome.incomplete;
    return RefreshOutcome.notModifiedRenewedAll;
  }

  bool sourcesCompatible(DateTime a, DateTime b) {
    return a.difference(b).abs() <= const Duration(minutes: 5);
  }

  bool deriveComplete<T>(T payload, List<PageEvidence> pages) {
    final missingPages = pages.any((page) => page.xPages == null);
    if (!missingPages) return true;
    if (payload is Iterable) return payload.isEmpty;
    return false;
  }
}
