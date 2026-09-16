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

  void calculate({required int quantity, required double rate}) {
    savedRate = rate;
    savedQuantity = quantity;
    previewRate = rate;
    previewQuantity = quantity;
  }

  void cancel() {}

  void save() {
    if (previewRate != null) savedRate = previewRate!;
    if (previewQuantity != null) savedQuantity = previewQuantity!;
  }
}

/// Naive C5 fuel: all block types count, no 25% bonus, 5m+1ms still compatible,
/// Calculate writes the saved scenario.
class CorporationFuelCalculator {
  const CorporationFuelCalculator();

  static const blockTypes = {4051, 4246, 4247, 4312};

  int? observedBlocks(List<FuelBayRow> rows) {
    var total = 0;
    for (final row in rows) {
      if (blockTypes.contains(row.typeId)) total += row.quantity;
    }
    return total;
  }

  FuelModelResult modeled({
    required int quantity,
    required int onlineConsumers,
    double reduction = 0.25,
    bool unsupportedConsumer = false,
  }) {
    final hourly = 12.0 * onlineConsumers;
    final daily = hourly * 24;
    final hours = quantity / hourly;
    return FuelModelResult(
      hourlyRate: hourly,
      dailyRate: daily,
      hours: hours,
      daysLabel: (hours / 24).toStringAsFixed(2),
      modeled: true,
    );
  }

  FuelModelResult manual({required int quantity, required double rate}) {
    return modeled(quantity: quantity, onlineConsumers: 2);
  }

  bool compatible(DateTime a, DateTime b) =>
      a.difference(b).abs().inMinutes <= 5;

  Duration reportedRemaining(DateTime expiresAt, DateTime now) =>
      expiresAt.difference(now);

  String severity(Duration? remaining) {
    if (remaining == null) return 'Normal';
    if (remaining >= const Duration(hours: 72)) return 'Normal';
    if (remaining >= const Duration(hours: 24)) return 'Low';
    if (remaining > Duration.zero) return 'Critical';
    return 'Reported expiry passed';
  }
}
