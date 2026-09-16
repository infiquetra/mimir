import 'corporation_decimal.dart';
import 'corporation_wallet.dart';

class JournalTotals {
  const JournalTotals({
    required this.inflow,
    required this.outflow,
    required this.net,
    required this.unknownCount,
    required this.includedIds,
    required this.rows,
  });

  final ExactDecimal inflow;
  final ExactDecimal outflow;
  final ExactDecimal net;
  final int unknownCount;
  final List<int> includedIds;
  final List<WalletJournalRow> rows;
}

class WalletTrade {
  const WalletTrade({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.isBuy,
    this.journalRefId = -1,
  });

  final int id;
  final int quantity;
  final ExactDecimal unitPrice;
  final bool isBuy;
  final int journalRefId;
}

/// Naive C6: inclusive end bound, null amounts become 0.00, float gross,
/// trades fold into journal cash, Bought/Sold labels.
class CorporationWalletCalculator {
  const CorporationWalletCalculator();

  JournalTotals summarize(
    List<WalletJournalRow> rows, {
    required DateTime from,
    required DateTime to,
    List<WalletTrade> trades = const [],
  }) {
    final included = [
      for (final row in rows)
        if (!row.occurredAt.isBefore(from) && !row.occurredAt.isAfter(to)) row,
    ]..sort((a, b) => a.id.compareTo(b.id));

    var inflow = 0.0;
    var outflow = 0.0;
    for (final row in included) {
      final amount = row.amount ?? ExactDecimal.parse('0.00');
      final value = double.parse(amount.toExactString());
      if (value > 0) inflow += value;
      if (value < 0) outflow += -value;
    }
    for (final trade in trades) {
      inflow += double.parse(
        tradeGross(
          quantity: trade.quantity,
          unitPrice: trade.unitPrice,
        ).toExactString(),
      );
    }
    return JournalTotals(
      inflow: ExactDecimal.fromNum(inflow),
      outflow: ExactDecimal.fromNum(outflow),
      net: ExactDecimal.fromNum(inflow - outflow),
      unknownCount: 0,
      includedIds: [for (final row in included) row.id],
      rows: [
        for (final row in included)
          WalletJournalRow(
            id: row.id,
            occurredAt: row.occurredAt,
            amount: row.amount ?? ExactDecimal.parse('0.00'),
            balance: row.balance,
            division: row.division,
            ownerCharacterId: row.ownerCharacterId,
          ),
      ],
    );
  }

  ExactDecimal tradeGross({
    required int quantity,
    required ExactDecimal unitPrice,
  }) {
    return ExactDecimal.fromNum(
      quantity * double.parse(unitPrice.toExactString()),
    );
  }

  String direction({required bool isBuy}) => isBuy ? 'Bought' : 'Sold';
}
