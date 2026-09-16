import '../domain/corporation_roster.dart';

/// Bounded public corporation-history loader: queue ≤50, concurrency ≤2, 24h TTL.
class PublicHistoryLoader {
  PublicHistoryLoader({
    this.ttl = const Duration(hours: 24),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const maxQueue = 50;
  static const maxConcurrent = 2;

  final Duration ttl;
  final DateTime Function() _now;
  final List<int> queued = [];
  var concurrent = 0;
  var fetches = 0;
  final Map<int, DateTime> _fetchedAt = {};

  void enqueue(Iterable<int> characterIds) {
    for (final id in characterIds) {
      if (_withinTtl(id)) continue;
      if (queued.contains(id)) continue;
      if (queued.length >= maxQueue) break;
      queued.add(id);
      _fetchedAt[id] = _now().toUtc();
      fetches += 1;
    }
    concurrent = queued.isEmpty
        ? 0
        : (queued.length < maxConcurrent ? queued.length : maxConcurrent);
  }

  bool _withinTtl(int id) {
    final at = _fetchedAt[id];
    if (at == null) return false;
    return _now().toUtc().difference(at) < ttl;
  }
}

/// Roster service: returned members only; denied enrichments lock independently.
class CorporationRosterService {
  CorporationRosterService({CorporationRoster? roster})
    : roster = roster ?? const CorporationRoster();

  final CorporationRoster roster;
  final history = PublicHistoryLoader();

  RosterSnapshot load({
    required List<int> returnedIds,
    required int publicCount,
    Map<int, List<Map<String, dynamic>>> history = const {},
    Map<int, DateTime> trackingStarts = const {},
    Map<int, DateTime?> lastLogins = const {},
    DateTime? now,
    int corporationId = 7001,
    bool trackingDenied = false,
    bool rolesDenied = false,
    bool titlesDenied = false,
  }) {
    final assembled = roster.assemble(
      returnedIds: returnedIds,
      publicCount: publicCount,
      history: history,
      trackingStarts: trackingDenied ? const {} : trackingStarts,
      lastLogins: trackingDenied ? const {} : lastLogins,
      now: now,
      corporationId: corporationId,
    );
    return RosterSnapshot(
      returnedIds: assembled.returnedIds,
      publicCount: assembled.publicCount,
      members: assembled.members,
      trackingLocked: trackingDenied,
      rolesLocked: rolesDenied,
      titlesLocked: titlesDenied,
    );
  }
}
