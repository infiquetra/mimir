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

/// Journal cash flow and trade gross. Trades never fold into journal net.
class CorporationWalletCalculator {
  const CorporationWalletCalculator();

  static final _zero = ExactDecimal(BigInt.zero, 0);

  JournalTotals summarize(
    List<WalletJournalRow> rows, {
    required DateTime from,
    required DateTime to,
    List<WalletTrade> trades = const [],
  }) {
    final included =
        [
          for (final row in rows)
            if (!row.occurredAt.isBefore(from) && row.occurredAt.isBefore(to))
              row,
        ]..sort((a, b) {
          final byDate = b.occurredAt.compareTo(a.occurredAt);
          if (byDate != 0) return byDate;
          return b.id.compareTo(a.id);
        });

    var inflow = _zero;
    var outflow = _zero;
    var unknownCount = 0;
    for (final row in included) {
      final amount = row.amount;
      if (amount == null) {
        unknownCount += 1;
        continue;
      }
      if (amount > _zero) {
        inflow += amount;
      } else if (amount < _zero) {
        outflow += ExactDecimal(-amount.coefficient, amount.scale);
      }
    }

    return JournalTotals(
      inflow: inflow,
      outflow: outflow,
      net: inflow - outflow,
      unknownCount: unknownCount,
      includedIds: [for (final row in included) row.id],
      rows: included,
    );
  }

  ExactDecimal tradeGross({
    required int quantity,
    required ExactDecimal unitPrice,
  }) {
    return ExactDecimal.fromNum(quantity) * unitPrice;
  }

  String direction({required bool isBuy}) => isBuy ? 'Buy' : 'Sell';
}
