// C6 RED: F5 seven-division balances, missing coverage, Division n names.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const wallet = CorporationWallet();
  const names = {2: 'Logistics', 7: 'Reserves'};

  List<WalletDivisionInput> f5({bool omitDivision7 = false}) {
    final raw = F5Fixtures.wallets()['balances'] as List;
    return [
      for (final row in raw)
        if (!(omitDivision7 && row['division'] == 7))
          WalletDivisionInput(
            division: row['division'] as int,
            balance: ExactDecimal.parse(row['balance'] as String),
          ),
    ];
  }

  test('F5 complete total is 1500.00 across seven divisions', () {
    final snapshot = wallet.publish(f5(), names: names);
    expect(snapshot.divisions.map((row) => row.division), [
      1,
      2,
      3,
      4,
      5,
      6,
      7,
    ]);
    expect(snapshot.knownCount, 7);
    expect(snapshot.knownTotal.toExactString(), '1500.00');
    expect(snapshot.divisions[2].balance!.toExactString(), '0.00');
    expect(snapshot.divisions[2].unknown, isFalse);
    expect(snapshot.divisions[3].balance!.toExactString(), '-10.05');
  });

  test('missing division 7 is 1200.00 (6/7), not a zero-filled seventh', () {
    final snapshot = wallet.publish(f5(omitDivision7: true), names: names);
    expect(snapshot.knownTotal.toExactString(), '1200.00');
    expect(snapshot.knownCount, 6);
    expect(snapshot.coverageLabel, contains('6/7'));
    expect(snapshot.divisions[6].division, 7);
    expect(snapshot.divisions[6].balance, isNull);
    expect(snapshot.divisions[6].unknown, isTrue);
  });

  test('custom names win; missing names use Division n', () {
    final snapshot = wallet.publish(f5(), names: names);
    expect(snapshot.divisions[0].name, 'Division 1');
    expect(snapshot.divisions[1].name, 'Logistics');
    expect(snapshot.divisions[6].name, 'Reserves');
  });

  test('Accountant can view wallets without Director', () {
    expect(wallet.canView(F1Fixtures.eren().evidence()), isTrue);
    expect(wallet.canView(F1Fixtures.finn().evidence()), isTrue);
    expect(wallet.canView(F1Fixtures.ada().evidence()), isFalse);
  });

  test('wallet total does not drift through double', () {
    final snapshot = wallet.publish([
      WalletDivisionInput(division: 1, balance: ExactDecimal.parse('0.1')),
      WalletDivisionInput(division: 2, balance: ExactDecimal.parse('0.2')),
    ]);
    expect(snapshot.knownTotal.toExactString(), '0.3');
  });
}
