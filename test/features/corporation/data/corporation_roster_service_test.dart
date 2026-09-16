// C3 RED: independently locked enrichments, bounded history loader, conservation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_roster_service.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  late CorporationRosterService service;

  setUp(() {
    service = CorporationRosterService();
  });

  Map<int, List<Map<String, dynamic>>> history() {
    final raw = F2Fixtures.roster()['history'] as Map;
    return {
      for (final entry in raw.entries)
        int.parse('${entry.key}'): [
          for (final row in entry.value as List)
            Map<String, dynamic>.from(row as Map),
        ],
    };
  }

  test('403 tracking/roles/titles lock enrichments and keep Ada+Bea', () {
    final snapshot = service.load(
      returnedIds: const [kAdaId, kBeaId],
      publicCount: 3,
      history: history(),
      now: kCorporationT0,
      corporationId: kHeliosId,
      trackingDenied: true,
      rolesDenied: true,
      titlesDenied: true,
    );
    expect(snapshot.members.map((m) => m.characterId), [kAdaId, kBeaId]);
    expect(snapshot.trackingLocked, isTrue);
    expect(snapshot.rolesLocked, isTrue);
    expect(snapshot.titlesLocked, isTrue);
  });

  test(
    'unmatched tracking 99 and former employment do not join the roster',
    () {
      final snapshot = service.load(
        returnedIds: const [kAdaId, kBeaId],
        publicCount: 3,
        history: history(),
        trackingStarts: {
          kAdaId: DateTime.utc(2026, 9, 2),
          99: DateTime.utc(2026, 9, 3),
        },
        now: kCorporationT0,
        corporationId: kHeliosId,
      );
      expect(snapshot.members.map((m) => m.characterId), [kAdaId, kBeaId]);
      expect(snapshot.members.any((m) => m.characterId == 99), isFalse);
    },
  );

  test('public history loader caps queue at 50 and concurrency at 2', () {
    service.history.enqueue(List<int>.generate(80, (i) => i + 1));
    expect(service.history.queued.length, lessThanOrEqualTo(50));
    expect(service.history.concurrent, lessThanOrEqualTo(2));
    expect(service.history.fetches, lessThanOrEqualTo(50));
  });

  test('same member is not fetched twice inside the 24h TTL', () {
    service.history.enqueue([kAdaId]);
    final first = service.history.fetches;
    service.history.enqueue([kAdaId]);
    expect(service.history.fetches, first);
    expect(service.history.ttl, const Duration(hours: 24));
  });
}
