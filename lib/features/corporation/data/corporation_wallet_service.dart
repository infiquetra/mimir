import '../domain/corporation_decimal.dart';
import '../domain/corporation_history_coverage.dart';
import '../domain/corporation_wallet.dart';

class CursorWalk {
  const CursorWalk({
    required this.ids,
    required this.fromIds,
    required this.complete,
    required this.loopDetected,
  });

  final List<int> ids;
  final List<int> fromIds;
  final bool complete;
  final bool loopDetected;
}

/// Cursor pagination, division isolation, and owner-scoped wallet storage.
class CorporationWalletService {
  CorporationWalletService();

  final Map<String, ExactDecimal> _balances = {};
  final List<WalletJournalRow> journal = [];

  String _key({
    required String owner,
    required int division,
    required String kind,
    required int corporationId,
  }) => '$kind/$owner/$corporationId/$division';

  CursorWalk followCursor(List<List<int>> pages) {
    final ids = <int>[];
    final seen = <int>{};
    final fromIds = <int>[];
    var complete = false;
    var loopDetected = false;
    int? previousOldest;

    for (final page in pages) {
      if (previousOldest != null) {
        fromIds.add(previousOldest);
      }
      if (page.isEmpty) {
        complete = true;
        break;
      }
      final oldest = page.reduce((a, b) => a < b ? a : b);
      if (previousOldest != null && oldest >= previousOldest) {
        loopDetected = true;
        for (final id in page) {
          if (seen.add(id)) ids.add(id);
        }
        break;
      }
      for (final id in page) {
        if (seen.add(id)) ids.add(id);
      }
      previousOldest = oldest;
    }

    return CursorWalk(
      ids: ids,
      fromIds: fromIds,
      complete: complete && !loopDetected,
      loopDetected: loopDetected,
    );
  }

  Map<int, ExactDecimal?> publishDivisions(
    Map<int, ExactDecimal> known, {
    int? failedDivision,
  }) {
    return {
      for (final entry in known.entries)
        if (entry.key != failedDivision) entry.key: entry.value,
    };
  }

  void putBalance({
    required String owner,
    required int division,
    required ExactDecimal amount,
    String kind = 'corporate',
    int corporationId = 0,
  }) {
    _balances[_key(
          owner: owner,
          division: division,
          kind: kind,
          corporationId: corporationId,
        )] =
        amount;
  }

  ExactDecimal? getBalance({
    required String owner,
    required int division,
    String kind = 'corporate',
    int corporationId = 0,
  }) {
    return _balances[_key(
      owner: owner,
      division: division,
      kind: kind,
      corporationId: corporationId,
    )];
  }

  WalletHistoryCoverage prune({
    required int ownerCharacterId,
    required DateTime now,
  }) {
    journal.removeWhere(
      (row) =>
          row.ownerCharacterId == ownerCharacterId &&
          now.difference(row.occurredAt) > const Duration(days: 365),
    );
    return const WalletHistoryCoverage(refetchableFromEsi: false);
  }
}
