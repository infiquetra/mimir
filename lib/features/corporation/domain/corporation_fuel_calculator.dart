import 'corporation_oracles.dart';

class FuelModelResult {
  const FuelModelResult({
    this.hourlyRate,
    this.dailyRate,
    this.hours,
    this.daysLabel,
    this.modeled = true,
  });

  final double? hourlyRate;
  final double? dailyRate;
  final double? hours;
  final String? daysLabel;
  final bool modeled;
}

class FuelScenarioDraft {
  FuelScenarioDraft({this.savedRate = 20, this.savedQuantity = 1440});

  double savedRate;
  int savedQuantity;
  double? previewRate;
  int? previewQuantity;

  /// Preview only. Does not mutate the saved scenario.
  void calculate({required int quantity, required double rate}) {
    previewRate = rate;
    previewQuantity = quantity;
  }

  void cancel() {
    previewRate = null;
    previewQuantity = null;
  }

  void save() {
    if (previewRate != null) savedRate = previewRate!;
    if (previewQuantity != null) savedQuantity = previewQuantity!;
  }
}

class CorporationFuelCalculator {
  const CorporationFuelCalculator();

  static const blockTypes = FuelOracle.blockTypes;
  static const _maxSkew = Duration(minutes: 5);

  int? observedBlocks(List<FuelBayRow> rows) {
    var total = 0;
    var qualifying = false;
    for (final row in rows) {
      if (!blockTypes.contains(row.typeId)) continue;
      if (row.flag != FuelOracle.structureFuelFlag) continue;
      if (row.nested || row.inShip) continue;
      qualifying = true;
      total += row.quantity;
    }
    if (!qualifying) return null;
    return total;
  }

  FuelModelResult modeled({
    required int quantity,
    required int onlineConsumers,
    double reduction = 0.25,
    bool unsupportedConsumer = false,
  }) {
    if (unsupportedConsumer || onlineConsumers <= 0) {
      return const FuelModelResult(modeled: false);
    }
    final hourly = FuelOracle.baseHourly * (1 - reduction) * onlineConsumers;
    return _fromRate(quantity: quantity, rate: hourly);
  }

  FuelModelResult manual({required int quantity, required double rate}) {
    if (rate == 0 || !rate.isFinite || rate < 0) {
      return const FuelModelResult(modeled: false);
    }
    return _fromRate(quantity: quantity, rate: rate);
  }

  /// Exact millisecond skew: 5m inclusive, 5m+1ms rejected.
  bool compatible(DateTime a, DateTime b) {
    return a.difference(b).abs() <= _maxSkew;
  }

  Duration reportedRemaining(DateTime expiresAt, DateTime now) =>
      expiresAt.difference(now);

  String severity(Duration? remaining) {
    if (remaining == null) return 'Unknown';
    if (remaining <= Duration.zero) return 'Reported expiry passed';
    if (remaining <= const Duration(hours: 24)) return 'Critical';
    if (remaining <= const Duration(hours: 72)) return 'Low';
    return 'Normal';
  }

  FuelModelResult _fromRate({required int quantity, required double rate}) {
    final daily = rate * 24;
    final hours = quantity / rate;
    return FuelModelResult(
      hourlyRate: rate,
      dailyRate: daily,
      hours: hours,
      daysLabel: (hours / 24).toStringAsFixed(2),
      modeled: true,
    );
  }
}
