// C3 RED: roster membership, F2 join provenance, UTC activity, titles, own access.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_roster.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const roster = CorporationRoster();

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

  RosterSnapshot helios({
    Map<int, DateTime> tracking = const {},
    Map<int, DateTime?> logins = const {},
    DateTime? now,
  }) {
    return roster.assemble(
      returnedIds: const [kAdaId, kBeaId],
      publicCount: 3,
      history: history(),
      trackingStarts: tracking,
      lastLogins: logins,
      now: now ?? kCorporationT0,
      corporationId: kHeliosId,
    );
  }

  group('membership set', () {
    test('roster is returned members [1,2] and reports count 3 mismatch', () {
      final snapshot = helios();
      expect(snapshot.returnedIds, [kAdaId, kBeaId]);
      expect(snapshot.publicCount, 3);
      expect(snapshot.members.map((m) => m.characterId), [kAdaId, kBeaId]);
      expect(snapshot.reportsCountMismatch, isTrue);
      expect(snapshot.members.any((m) => m.characterId == 99), isFalse);
    });
  });

  group('join date provenance', () {
    test('Ada current join is 1 Sep from record 9, not 1 Jan', () {
      final ada = helios().members.singleWhere((m) => m.characterId == kAdaId);
      expect(ada.join.at, DateTime.utc(2026, 9, 1));
      expect(ada.join.source, JoinSource.publicHistory);
    });

    test('Bea latest Selene record leaves Helios join unavailable', () {
      final bea = helios().members.singleWhere((m) => m.characterId == kBeaId);
      expect(bea.join.at, isNull);
      expect(bea.join.source, JoinSource.unavailable);
    });

    test('authorized tracking start_date 2 Sep overrides public history', () {
      final ada = helios(
        tracking: {kAdaId: DateTime.utc(2026, 9, 2)},
      ).members.singleWhere((m) => m.characterId == kAdaId);
      expect(ada.join.at, DateTime.utc(2026, 9, 2));
      expect(ada.join.source, JoinSource.tracking);
    });
  });

  group('activity filters', () {
    final adaLogin = DateTime.utc(2026, 9, 8, 12);

    test('7/30/90 day filters include Ada at T0 and exclude at T0+1ms', () {
      expect(
        roster.inActivityFilter(
          login: adaLogin,
          now: kCorporationT0,
          bucket: ActivityBucket.last7,
        ),
        isTrue,
      );
      expect(
        roster.inActivityFilter(
          login: adaLogin,
          now: kCorporationT0.add(const Duration(milliseconds: 1)),
          bucket: ActivityBucket.last7,
        ),
        isFalse,
      );
      final thirtyAgo = DateTime.utc(2026, 8, 16, 12);
      expect(
        roster.inActivityFilter(
          login: thirtyAgo,
          now: kCorporationT0,
          bucket: ActivityBucket.last30,
        ),
        isTrue,
      );
      expect(
        roster.inActivityFilter(
          login: thirtyAgo,
          now: kCorporationT0.add(const Duration(milliseconds: 1)),
          bucket: ActivityBucket.last30,
        ),
        isFalse,
      );
      final ninetyAgo = DateTime.utc(2026, 6, 17, 12);
      expect(
        roster.inActivityFilter(
          login: ninetyAgo,
          now: kCorporationT0,
          bucket: ActivityBucket.last90,
        ),
        isTrue,
      );
      expect(
        roster.inActivityFilter(
          login: ninetyAgo,
          now: kCorporationT0.add(const Duration(milliseconds: 1)),
          bucket: ActivityBucket.last90,
        ),
        isFalse,
      );
    });

    test(
      'missing login is Not reported; future login is Unknown, never Online',
      () {
        final snapshot = helios(
          logins: {
            kAdaId: kCorporationT0.add(const Duration(hours: 1)),
            kBeaId: null,
          },
        );
        final ada = snapshot.members.singleWhere(
          (m) => m.characterId == kAdaId,
        );
        final bea = snapshot.members.singleWhere(
          (m) => m.characterId == kBeaId,
        );
        expect(ada.status, ActivityStatus.unknown);
        expect(ada.online, isFalse);
        expect(bea.status, ActivityStatus.notReported);
        expect(bea.online, isFalse);
        expect(
          roster.inActivityFilter(
            login: null,
            now: kCorporationT0,
            bucket: ActivityBucket.notReported,
          ),
          isTrue,
        );
      },
    );

    test('login newer than logout is not rendered Online', () {
      final snapshot = helios(
        logins: {kAdaId: kCorporationT0.subtract(const Duration(hours: 1))},
      );
      expect(
        snapshot.members.singleWhere((m) => m.characterId == kAdaId).online,
        isFalse,
      );
    });
  });

  group('titles and own access', () {
    test(
      'title names do not confer Director; locked titles are unavailable',
      () {
        expect(roster.titleGrantsDirector('Director of Operations'), isFalse);
        expect(
          roster.titleLabel(
            titleId: 5,
            name: 'Director of Operations',
            locked: true,
          ),
          'title unavailable',
        );
        expect(
          roster.titleLabel(titleId: 5, locked: true),
          isNot(contains('5')),
        );
      },
    );

    test(
      'own-access matrix keeps HQ query distinct and NPC standings caption',
      () {
        final matrix = const OwnAccessProjector().project(
          F1Fixtures.ada().evidence(),
        );
        expect(matrix.standingsCaption, 'My NPC standings');
        final hqQuery = matrix.cells.where((cell) => cell.division == 1);
        expect(hqQuery, isNotEmpty);
        expect(hqQuery.first.value, anyOf('Yes', 'Not reported', 'Unknown'));
        expect(
          matrix.cells.where((cell) => cell.value == 'Yes'),
          isNot(hasLength(7)),
        );
      },
    );
  });
}
