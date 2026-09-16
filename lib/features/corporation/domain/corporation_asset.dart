import 'corporation_decimal.dart';
import 'corporation_oracles.dart';

class AssetRecord {
  const AssetRecord({
    required this.itemId,
    required this.typeId,
    required this.quantity,
    required this.locationId,
    required this.locationType,
    this.flag = '',
    this.rawQuantity,
    this.isBlueprintCopy = false,
    this.administrative = false,
  });

  final int itemId;
  final int typeId;
  final num quantity;
  final int locationId;
  final String locationType;
  final String flag;
  final int? rawQuantity;
  final bool isBlueprintCopy;
  final bool administrative;

  bool get isBpc => isBlueprintCopy || rawQuantity == -2;

  bool get isGoods => !administrative;

  bool get hasUnknownQuantity => quantity < 0;

  factory AssetRecord.fromRow(CorporateAssetRow row) {
    return AssetRecord(
      itemId: row.itemId,
      typeId: row.typeId,
      quantity: row.quantity,
      locationId: row.locationId,
      locationType: row.locationType,
      flag: row.flag,
      rawQuantity: row.isBlueprintCopy ? -2 : row.quantity.toInt(),
      isBlueprintCopy: row.isBlueprintCopy,
      administrative: row.administrative,
    );
  }
}

class AssetValuationResult {
  AssetValuationResult({
    required this.pricedSubtotal,
    this.goodsCount = 0,
    this.pricedCount = 0,
    this.unpricedCount = 0,
    ExactDecimal? division1,
    ExactDecimal? division2,
    this.division7Unpriced = 0,
    ExactDecimal? unresolvedPriced,
  }) : division1 = division1 ?? ExactDecimal.parse('0.00'),
       division2 = division2 ?? ExactDecimal.parse('0.00'),
       unresolvedPriced = unresolvedPriced ?? ExactDecimal.parse('0.00');

  final ExactDecimal pricedSubtotal;
  final int goodsCount;
  final int pricedCount;
  final int unpricedCount;
  final ExactDecimal division1;
  final ExactDecimal division2;
  final int division7Unpriced;
  final ExactDecimal unresolvedPriced;
}

/// Exact fold over distinct goods rows. Office/BPC/unknown quantity or
/// missing quote are unpriced, never 0 ISK or adjusted-price fallbacks.
class CorporationAssetValuation {
  const CorporationAssetValuation();

  static final _zero = ExactDecimal(BigInt.zero, 2);

  AssetValuationResult value(
    List<AssetRecord> rows,
    Map<int, ExactDecimal> prices,
  ) {
    final byId = {for (final row in rows) row.itemId: row};
    var pricedSum = ExactDecimal(BigInt.zero, 0);
    var division1 = ExactDecimal(BigInt.zero, 0);
    var division2 = ExactDecimal(BigInt.zero, 0);
    var unresolved = ExactDecimal(BigInt.zero, 0);
    var goods = 0;
    var priced = 0;
    var unpriced = 0;
    var division7Unpriced = 0;

    for (final row in rows) {
      if (!row.isGoods) continue;
      goods += 1;
      final division = _division(row, byId);
      final line = _pricedLine(row, prices);
      if (line == null) {
        unpriced += 1;
        if (division == 7) division7Unpriced += 1;
        continue;
      }
      priced += 1;
      pricedSum += line;
      if (division == 1) division1 += line;
      if (division == 2) division2 += line;
      if (division == null) unresolved += line;
    }

    return AssetValuationResult(
      pricedSubtotal: _money(pricedSum),
      goodsCount: goods,
      pricedCount: priced,
      unpricedCount: unpriced,
      division1: _money(division1),
      division2: _money(division2),
      division7Unpriced: division7Unpriced,
      unresolvedPriced: _money(unresolved),
    );
  }

  ExactDecimal? _pricedLine(AssetRecord row, Map<int, ExactDecimal> prices) {
    if (row.isBpc || row.hasUnknownQuantity) return null;
    final unit = prices[row.typeId];
    if (unit == null) return null;
    return unit * ExactDecimal.fromNum(row.quantity);
  }

  int? _division(AssetRecord row, Map<int, AssetRecord> byId) {
    AssetRecord? current = row;
    final seen = <int>{};
    while (current != null && seen.add(current.itemId)) {
      final sag = _corpSag(current.flag);
      if (sag != null) return sag;
      if (current.locationType != 'item') return null;
      current = byId[current.locationId];
    }
    return null;
  }

  int? _corpSag(String flag) {
    final match = RegExp(r'^CorpSAG([1-7])$').firstMatch(flag);
    if (match == null) return null;
    return int.parse(match.group(1)!);
  }

  ExactDecimal _money(ExactDecimal value) {
    if (value.coefficient == BigInt.zero && value.scale == 0) return _zero;
    return value.roundTo(2);
  }
}
