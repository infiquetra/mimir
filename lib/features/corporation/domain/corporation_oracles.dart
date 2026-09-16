import 'corporation_decimal.dart';
import 'corporation_snapshot.dart';

class CorporateAssetRow {
  const CorporateAssetRow({
    required this.itemId,
    required this.typeId,
    required this.quantity,
    required this.locationId,
    required this.locationType,
    this.flag = '',
    this.isBlueprintCopy = false,
    this.administrative = false,
  });

  final int itemId;
  final int typeId;
  final num quantity;
  final int locationId;
  final String locationType;
  final String flag;
  final bool isBlueprintCopy;
  final bool administrative;
}

class TypeQuote {
  const TypeQuote({required this.typeId, this.price, this.name = ''});
  final int typeId;
  final ExactDecimal? price;
  final String name;
}

/// Goods valuation: skip BPC, skip unpriced, skip administrative nodes.
class AssetValuation {
  const AssetValuation();

  ExactDecimal pricedSubtotal(
    List<CorporateAssetRow> rows,
    Map<int, ExactDecimal> prices,
  ) {
    var sum = ExactDecimal(BigInt.zero, 0);
    for (final row in rows) {
      if (row.administrative || row.isBlueprintCopy) continue;
      final price = prices[row.typeId];
      if (price == null) continue;
      sum += price * ExactDecimal.fromNum(row.quantity);
    }
    return sum;
  }

  List<CorporateAssetRow> search(
    List<CorporateAssetRow> rows,
    String query,
    Map<int, String> names,
  ) {
    final needle = query.toLowerCase();
    return [
      for (final row in rows)
        if ((names[row.typeId] ?? '').toLowerCase().contains(needle)) row,
    ];
  }
}

class FuelBayRow {
  const FuelBayRow({
    required this.typeId,
    required this.quantity,
    required this.flag,
    this.nested = false,
    this.inShip = false,
  });

  final int typeId;
  final int quantity;
  final String flag;
  final bool nested;
  final bool inShip;
}

/// Direct StructureFuel bay blocks only. Rate is 12×(1−reduction) per consumer.
class FuelOracle {
  static const blockTypes = {4051, 4246, 4247, 4312};
  static const structureFuelFlag = 'StructureFuel';
  static const baseHourly = 12.0;

  int observedBlocks(List<FuelBayRow> rows) {
    var total = 0;
    for (final row in rows) {
      if (!blockTypes.contains(row.typeId)) continue;
      if (row.flag != structureFuelFlag) continue;
      if (row.nested || row.inShip) continue;
      total += row.quantity;
    }
    return total;
  }

  double hourlyRate({required int onlineConsumers, double reduction = 0.25}) {
    return baseHourly * (1 - reduction) * onlineConsumers;
  }

  Duration reportedRemaining(DateTime expiresAt, DateTime now) =>
      expiresAt.difference(now);

  String severity(Duration remaining) {
    if (remaining <= Duration.zero) return 'Reported expiry passed';
    if (remaining <= const Duration(hours: 24)) return 'Critical';
    if (remaining <= const Duration(hours: 72)) return 'Low';
    return 'Normal';
  }

  bool compatible(DateTime a, DateTime b) =>
      const SnapshotFreshness().sourcesCompatible(a, b);
}

class WalletOracle {
  ExactDecimal total(List<ExactDecimal?> balances) {
    var sum = ExactDecimal(BigInt.zero, 0);
    for (final balance in balances) {
      if (balance == null) continue;
      sum += balance;
    }
    return sum;
  }

  /// End-exclusive journal window. F5 id 107 is dated at the exclusive end.
  List<int> includeJournal(List<int> ids, DateTime endExclusive) {
    return [
      for (final id in ids)
        if (_journalDate(id).isBefore(endExclusive)) id,
    ];
  }

  List<int> followCursor(List<List<int>> pages) {
    final seen = <int>{};
    final ordered = <int>[];
    for (final page in pages) {
      for (final id in page) {
        if (seen.add(id)) ordered.add(id);
      }
    }
    return ordered;
  }

  ExactDecimal tradeGross({
    required int quantity,
    required ExactDecimal price,
  }) {
    return ExactDecimal.fromNum(quantity) * price;
  }

  DateTime _journalDate(int id) {
    return switch (id) {
      107 => DateTime.utc(2026, 9, 16),
      _ => DateTime.utc(2026, 9, 15),
    };
  }
}

/// Public history: descending record_id, current episode must match corporation.
class RosterOracle {
  DateTime? currentJoin(List<dynamic> history, int corporationId) {
    final rows = [
      for (final row in history) Map<String, dynamic>.from(row as Map),
    ];
    rows.sort((a, b) {
      final idA = (a['record_id'] as num?)?.toInt() ?? 0;
      final idB = (b['record_id'] as num?)?.toInt() ?? 0;
      return idB.compareTo(idA);
    });
    if (rows.isEmpty) return null;
    final latest = rows.first;
    if (latest['corporation_id'] != corporationId) return null;
    final raw = latest['start_date']?.toString();
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  bool withinSevenDays(DateTime login, DateTime now) {
    return now.difference(login) <= const Duration(days: 7);
  }
}
