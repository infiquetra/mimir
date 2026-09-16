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

/// Naive freshness: receivedAt + max-age, which double-counts or ignores Age.
class SnapshotFreshness {
  const SnapshotFreshness();

  DateTime deadline({
    required DateTime receivedAt,
    DateTime? dateHeader,
    int? ageSeconds,
    int maxAgeSeconds = 3600,
  }) {
    return receivedAt.add(Duration(seconds: maxAgeSeconds));
  }

  bool offlineReadAllowed({
    required DateTime now,
    required DateTime leaseEndsAt,
  }) {
    return !now.isAfter(leaseEndsAt);
  }

  RefreshOutcome applyNotModified({required bool pageOneOnly}) {
    return RefreshOutcome.notModifiedRenewedAll;
  }

  bool sourcesCompatible(DateTime a, DateTime b) {
    return a.difference(b).abs().inMinutes <= 5;
  }

  bool deriveComplete<T>(T payload, List<PageEvidence> pages) => true;
}
