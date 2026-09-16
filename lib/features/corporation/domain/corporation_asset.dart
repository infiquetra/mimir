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
  }) : division1 = division1 ?? ExactDecimal.parse('0'),
       division2 = division2 ?? ExactDecimal.parse('0'),
       unresolvedPriced = unresolvedPriced ?? ExactDecimal.parse('0');

  final ExactDecimal pricedSubtotal;
  final int goodsCount;
  final int pricedCount;
  final int unpricedCount;
  final ExactDecimal division1;
  final ExactDecimal division2;
  final int division7Unpriced;
  final ExactDecimal unresolvedPriced;
}

/// Naive C4 valuation: includes BPC/office, missing quotes as 0, own-flag
/// hangars only, double arithmetic.
class CorporationAssetValuation {
  const CorporationAssetValuation();

  AssetValuationResult value(
    List<AssetRecord> rows,
    Map<int, ExactDecimal> prices,
  ) {
    var total = 0.0;
    var d1 = 0.0;
    var d2 = 0.0;
    var unresolved = 0.0;
    var goods = 0;
    var priced = 0;
    var div7 = 0;
    for (final row in rows) {
      goods += 1;
      final unit = prices[row.typeId];
      final line =
          (unit == null ? 0.0 : double.parse(unit.toExactString())) *
          row.quantity.toDouble();
      total += line;
      if (unit != null) priced += 1;
      if (row.flag == 'CorpSAG1') d1 += line;
      if (row.flag == 'CorpSAG2') d2 += line;
      if (row.flag == 'CorpSAG7') div7 += 1;
      if (row.locationId == 999 || row.itemId == 1400 || row.itemId == 1401) {
        unresolved += line;
      }
    }
    return AssetValuationResult(
      pricedSubtotal: ExactDecimal.fromNum(total),
      goodsCount: goods,
      pricedCount: priced,
      unpricedCount: 0,
      division1: ExactDecimal.fromNum(d1),
      division2: ExactDecimal.fromNum(d2),
      division7Unpriced: div7,
      unresolvedPriced: ExactDecimal.fromNum(unresolved),
    );
  }
}
