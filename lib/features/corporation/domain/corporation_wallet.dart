import 'corporation_access.dart';
import 'corporation_decimal.dart';

class WalletDivisionInput {
  const WalletDivisionInput({required this.division, this.balance});

  final int division;
  final ExactDecimal? balance;
}

class WalletDivision {
  const WalletDivision({required this.division, this.balance, this.name = ''});

  final int division;
  final ExactDecimal? balance;
  final String name;

  bool get unknown => balance == null;
}

class WalletBalanceSnapshot {
  const WalletBalanceSnapshot({
    required this.divisions,
    required this.knownTotal,
    required this.knownCount,
    required this.coverageLabel,
  });

  final List<WalletDivision> divisions;
  final ExactDecimal knownTotal;
  final int knownCount;
  final String coverageLabel;
}

class WalletJournalRow {
  const WalletJournalRow({
    required this.id,
    required this.occurredAt,
    this.amount,
    this.balance,
    this.division = 2,
    this.ownerCharacterId = 0,
  });

  final int id;
  final DateTime occurredAt;
  final ExactDecimal? amount;
  final ExactDecimal? balance;
  final int division;
  final int ownerCharacterId;
}

/// Naive C6: missing balances become 0.00, names ignore custom labels,
/// Accountant requires Director, totals go through [double].
class CorporationWallet {
  const CorporationWallet();

  bool canView(RoleEvidence roles) => roles.isDirector;

  WalletBalanceSnapshot publish(
    List<WalletDivisionInput> rows, {
    Map<int, String> names = const {},
  }) {
    final byDivision = {for (final row in rows) row.division: row};
    final divisions = <WalletDivision>[];
    var acc = 0.0;
    var known = 0;
    for (var n = 1; n <= 7; n++) {
      final amount = byDivision[n]?.balance ?? ExactDecimal.parse('0.00');
      acc += double.parse(amount.toExactString());
      known += 1;
      divisions.add(
        WalletDivision(division: n, balance: amount, name: 'Division $n'),
      );
    }
    return WalletBalanceSnapshot(
      divisions: divisions,
      knownTotal: ExactDecimal.fromNum(acc),
      knownCount: known,
      coverageLabel: 'All divisions',
    );
  }
}
