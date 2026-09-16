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

/// Naive C6: cursor concatenates duplicates, any division failure wipes
/// the snapshot, storage keys ignore kind/corporation, prune is unscoped.
class CorporationWalletService {
  CorporationWalletService();

  final Map<String, ExactDecimal> _balances = {};
  final List<WalletJournalRow> journal = [];

  String _key({required String owner, required int division}) =>
      '$owner/$division';

  CursorWalk followCursor(List<List<int>> pages) {
    return CursorWalk(
      ids: [for (final page in pages) ...page],
      fromIds: const [],
      complete: true,
      loopDetected: false,
    );
  }

  Map<int, ExactDecimal?> publishDivisions(
    Map<int, ExactDecimal> known, {
    int? failedDivision,
  }) {
    if (failedDivision != null) return {};
    return {for (final entry in known.entries) entry.key: entry.value};
  }

  void putBalance({
    required String owner,
    required int division,
    required ExactDecimal amount,
    String kind = 'corporate',
    int corporationId = 0,
  }) {
    _balances[_key(owner: owner, division: division)] = amount;
  }

  ExactDecimal? getBalance({
    required String owner,
    required int division,
    String kind = 'corporate',
    int corporationId = 0,
  }) {
    return _balances[_key(owner: owner, division: division)];
  }

  WalletHistoryCoverage prune({
    required int ownerCharacterId,
    required DateTime now,
  }) {
    journal.removeWhere((row) => now.difference(row.occurredAt).inDays >= 365);
    return const WalletHistoryCoverage();
  }
}
