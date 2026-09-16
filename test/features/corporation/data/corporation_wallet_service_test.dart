// C6 RED: F5 cursor walk, division isolation, personal collision, 365-day prune.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/data/corporation_wallet_service.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  List<List<int>> f5CursorPages() {
    return [
      for (final page in F5Fixtures.wallets()['cursor_pages'] as List)
        List<int>.from(page as List),
    ];
  }

  test('cursor [900, 899] → [899, 898] → [] yields three unique trades', () {
    final walk = CorporationWalletService().followCursor(f5CursorPages());
    expect(walk.ids, [900, 899, 898]);
    expect(walk.ids, hasLength(3));
    expect(walk.fromIds, [899, 898]);
    expect(walk.complete, isTrue);
    expect(walk.loopDetected, isFalse);
  });

  test('non-progressing cursor is a loop, not completion', () {
    final walk = CorporationWalletService().followCursor(const [
      [900, 899],
      [900, 899],
    ]);
    expect(walk.loopDetected, isTrue);
    expect(walk.complete, isFalse);
    expect(walk.ids.toSet(), {900, 899});
  });

  test('division 7 failure does not clear or overwrite divisions 1-6', () {
    final known = <int, ExactDecimal>{
      for (final row in F5Fixtures.wallets()['balances'] as List)
        if (row['division'] != 7)
          row['division'] as int: ExactDecimal.parse(row['balance'] as String),
    };
    final published = CorporationWalletService().publishDivisions(
      known,
      failedDivision: 7,
    );
    expect(published[1]?.toExactString(), '1000.10');
    expect(published[6]?.toExactString(), '4.20');
    expect(published.containsKey(7), isFalse);
    expect(published.length, 6);
  });

  test(
    'personal wallet storage does not collide with corporate division 2',
    () {
      final service = CorporationWalletService();
      service.putBalance(
        owner: 'cyra',
        division: 2,
        corporationId: kHeliosId,
        kind: 'corporate',
        amount: ExactDecimal.parse('200.20'),
      );
      service.putBalance(
        owner: 'cyra',
        division: 2,
        corporationId: 0,
        kind: 'personal',
        amount: ExactDecimal.parse('99.00'),
      );
      expect(
        service
            .getBalance(
              owner: 'cyra',
              division: 2,
              corporationId: kHeliosId,
              kind: 'corporate',
            )!
            .toExactString(),
        '200.20',
      );
      expect(
        service
            .getBalance(
              owner: 'cyra',
              division: 2,
              corporationId: 0,
              kind: 'personal',
            )!
            .toExactString(),
        '99.00',
      );
    },
  );

  test('365-day prune is owner-scoped and does not promise ESI recovery', () {
    final service = CorporationWalletService();
    service.journal.addAll([
      WalletJournalRow(
        id: 1,
        occurredAt: kCorporationT0,
        ownerCharacterId: kAdaId,
        amount: ExactDecimal.parse('1.00'),
      ),
      WalletJournalRow(
        id: 2,
        occurredAt: kCorporationT0.subtract(const Duration(days: 365)),
        ownerCharacterId: kAdaId,
        amount: ExactDecimal.parse('2.00'),
      ),
      WalletJournalRow(
        id: 3,
        occurredAt: kCorporationT0.subtract(const Duration(days: 366)),
        ownerCharacterId: kAdaId,
        amount: ExactDecimal.parse('3.00'),
      ),
      WalletJournalRow(
        id: 4,
        occurredAt: kCorporationT0.subtract(const Duration(days: 400)),
        ownerCharacterId: kCyraId,
        amount: ExactDecimal.parse('4.00'),
      ),
    ]);
    final coverage = service.prune(
      ownerCharacterId: kAdaId,
      now: kCorporationT0,
    );
    expect(service.journal.map((row) => row.id), containsAll([1, 2, 4]));
    expect(service.journal.map((row) => row.id), isNot(contains(3)));
    expect(coverage.refetchableFromEsi, isFalse);
  });
}
