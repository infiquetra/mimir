// C6 RED: F5 journal inflow/outflow/net, half-open bound, null amount, gross.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_decimal.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet.dart';
import 'package:mimir/features/corporation/domain/corporation_wallet_calculator.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const calculator = CorporationWalletCalculator();
  final from = DateTime.utc(2026, 9, 15);
  final to = DateTime.utc(2026, 9, 16);

  List<WalletJournalRow> f5Journal() {
    final raw = F5Fixtures.wallets()['journal'] as List;
    return [
      for (final row in raw)
        WalletJournalRow(
          id: row['id'] as int,
          occurredAt: DateTime.parse(row['date'] as String).toUtc(),
          amount: row['amount'] == null
              ? null
              : ExactDecimal.parse(row['amount'] as String),
          balance: row['balance'] == null
              ? null
              : ExactDecimal.parse(row['balance'] as String),
        ),
    ];
  }

  final buy = WalletTrade(
    id: 900,
    quantity: 3,
    unitPrice: ExactDecimal.parse('1.005'),
    isBuy: true,
    journalRefId: 102,
  );
  final sell = WalletTrade(
    id: 899,
    quantity: 2,
    unitPrice: ExactDecimal.parse('10.00'),
    isBuy: false,
    journalRefId: -1,
  );

  test('F5 journal is 100.40 inflow, 35.40 outflow, 65.00 net', () {
    final totals = calculator.summarize(f5Journal(), from: from, to: to);
    expect(totals.inflow.toExactString(), '100.40');
    expect(totals.outflow.toExactString(), '35.40');
    expect(totals.net.toExactString(), '65.00');
    expect(totals.unknownCount, 1);
    expect(totals.includedIds, [106, 105, 104, 103, 102, 101]);
  });

  test('half-open interval excludes ID 107 at the exclusive end', () {
    final totals = calculator.summarize(f5Journal(), from: from, to: to);
    expect(totals.includedIds, isNot(contains(107)));
    expect(totals.includedIds, hasLength(6));
  });

  test('null amount stays null and is not coerced to 0.00', () {
    final totals = calculator.summarize(f5Journal(), from: from, to: to);
    final unknown = totals.rows.singleWhere((row) => row.id == 105);
    expect(unknown.amount, isNull);
    expect(totals.unknownCount, 1);
  });

  test(
    'trade 1.005 x 3 is 3.015 displayed 3.02 Buy; 2 x 10.00 is 20.00 Sell',
    () {
      final buyGross = calculator.tradeGross(
        quantity: buy.quantity,
        unitPrice: buy.unitPrice,
      );
      expect(buyGross.toExactString(), '3.015');
      expect(buyGross.roundTo(2).toExactString(), '3.02');
      expect(calculator.direction(isBuy: true), 'Buy');
      final sellGross = calculator.tradeGross(
        quantity: sell.quantity,
        unitPrice: sell.unitPrice,
      );
      expect(sellGross.toExactString(), '20.00');
      expect(calculator.direction(isBuy: false), 'Sell');
    },
  );

  test('loaded trades do not change journal net 65.00', () {
    final totals = calculator.summarize(
      f5Journal(),
      from: from,
      to: to,
      trades: [buy, sell],
    );
    expect(totals.net.toExactString(), '65.00');
  });
}
