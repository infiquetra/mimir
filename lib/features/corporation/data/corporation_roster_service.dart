import '../domain/corporation_roster.dart';

class PublicHistoryLoader {
  PublicHistoryLoader({this.ttl = const Duration(hours: 24)});

  final Duration ttl;
  final List<int> queued = [];
  var concurrent = 0;
  var fetches = 0;

  void enqueue(Iterable<int> characterIds) {
    queued.addAll(characterIds);
    concurrent = queued.length;
    fetches += characterIds.length;
  }
}

/// Naive C3 service: 403 clears the roster, tracking 99 becomes a member,
/// and history fan-out is unbounded.
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
    if (trackingDenied || rolesDenied || titlesDenied) {
      return const RosterSnapshot(returnedIds: [], publicCount: 0, members: []);
    }
    final assembled = roster.assemble(
      returnedIds: returnedIds,
      publicCount: publicCount,
      history: history,
      trackingStarts: trackingStarts,
      lastLogins: lastLogins,
      now: now,
      corporationId: corporationId,
    );
    this.history.enqueue(assembled.members.map((m) => m.characterId));
    return assembled;
  }
}
