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

/// Seven-division corporate wallet snapshot. Missing divisions stay unknown.
class CorporationWallet {
  const CorporationWallet();

  bool canView(RoleEvidence roles) => roles.isAccountant || roles.isDirector;

  WalletBalanceSnapshot publish(
    List<WalletDivisionInput> rows, {
    Map<int, String> names = const {},
  }) {
    final byDivision = <int, ExactDecimal?>{};
    for (final row in rows) {
      if (row.division < 1 || row.division > 7) continue;
      byDivision[row.division] = row.balance;
    }

    final divisions = <WalletDivision>[];
    var knownTotal = ExactDecimal(BigInt.zero, 0);
    var knownCount = 0;
    for (var n = 1; n <= 7; n++) {
      final present = byDivision.containsKey(n);
      final amount = present ? byDivision[n] : null;
      if (present && amount != null) {
        knownTotal += amount;
        knownCount += 1;
      } else if (present && amount == null) {
        knownCount += 1;
      }
      final custom = names[n];
      divisions.add(
        WalletDivision(
          division: n,
          balance: amount,
          name: (custom != null && custom.isNotEmpty) ? custom : 'Division $n',
        ),
      );
    }
    return WalletBalanceSnapshot(
      divisions: divisions,
      knownTotal: knownTotal,
      knownCount: knownCount,
      coverageLabel: '$knownCount/7',
    );
  }
}
