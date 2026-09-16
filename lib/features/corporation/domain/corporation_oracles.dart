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

/// Naive valuation: prices BPC, counts ancestors as matches, uses double.
class AssetValuation {
  const AssetValuation();

  ExactDecimal pricedSubtotal(
    List<CorporateAssetRow> rows,
    Map<int, ExactDecimal> prices,
  ) {
    var sum = ExactDecimal.parse('0');
    for (final row in rows) {
      final price = prices[row.typeId] ?? ExactDecimal.parse('0');
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
    final ids = <int>{};
    for (final row in rows) {
      if ((names[row.typeId] ?? '').toLowerCase().contains(needle)) {
        ids.add(row.itemId);
        ids.add(row.locationId);
      }
    }
    return [
      for (final row in rows)
        if (ids.contains(row.itemId)) row,
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

/// Naive fuel: sums every fuel-block type regardless of flag/location.
class FuelOracle {
  static const blockTypes = {4051, 4246, 4247, 4312};

  int observedBlocks(List<FuelBayRow> rows) {
    var total = 0;
    for (final row in rows) {
      if (blockTypes.contains(row.typeId)) total += row.quantity;
    }
    return total;
  }

  double hourlyRate({required int onlineConsumers, double reduction = 0.25}) {
    return 12.0 * onlineConsumers;
  }

  Duration reportedRemaining(DateTime expiresAt, DateTime now) =>
      expiresAt.difference(now);

  String severity(Duration remaining) {
    if (remaining >= const Duration(hours: 72)) return 'Normal';
    if (remaining >= const Duration(hours: 24)) return 'Low';
    if (remaining > Duration.zero) return 'Critical';
    return 'Reported expiry passed';
  }

  bool compatible(DateTime a, DateTime b) =>
      SnapshotFreshness().sourcesCompatible(a, b);
}

class WalletOracle {
  ExactDecimal total(List<ExactDecimal?> balances) {
    var sum = ExactDecimal.parse('0');
    for (final balance in balances) {
      sum += balance ?? ExactDecimal.parse('0');
    }
    return sum;
  }

  List<int> includeJournal(List<int> ids, DateTime endExclusive) => ids;

  List<int> followCursor(List<List<int>> pages) {
    final seen = <int>[];
    for (final page in pages) {
      seen.addAll(page);
    }
    return seen;
  }

  ExactDecimal tradeGross({
    required int quantity,
    required ExactDecimal price,
  }) {
    return ExactDecimal.fromNum(quantity) * price;
  }
}
