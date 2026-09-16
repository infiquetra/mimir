// C5 RED: F4 expiry, bay blocks, modeled 18/h, 5m skew, manual scenario, save.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_calculator.dart';

import '../../../fixtures/corporation/corporation_fixtures.dart';

void main() {
  const calculator = CorporationFuelCalculator();

  test('F4 expiry is 216000s, 60h, 2.50 days, Low', () {
    final remaining = calculator.reportedRemaining(
      F4Fixtures.expiresAt,
      kCorporationT0,
    );
    expect(remaining.inSeconds, 216000);
    expect(remaining.inHours, 60);
    expect((remaining.inSeconds / 86400).toStringAsFixed(2), '2.50');
    expect(calculator.severity(remaining), 'Low');
  });

  test('observed bay is 1440 StructureFuel blocks only', () {
    expect(calculator.observedBlocks(F4Fixtures.bay()), 1440);
    expect(calculator.observedBlocks(const []), isNull);
  });

  test('two online 9/h consumers are 18/h, 432/day, 80h, 3.33 days', () {
    final model = calculator.modeled(quantity: 1440, onlineConsumers: 2);
    expect(model.hourlyRate, 18);
    expect(model.dailyRate, 432);
    expect(model.hours, 80);
    expect(model.daysLabel, '3.33');
  });

  test('unsupported consumer is Not modeled', () {
    final model = calculator.modeled(
      quantity: 1440,
      onlineConsumers: 2,
      unsupportedConsumer: true,
    );
    expect(model.modeled, isFalse);
    expect(model.hours, isNull);
  });

  test('5m skew qualifies and 5m+1ms does not', () {
    final a = kCorporationT0;
    expect(calculator.compatible(a, a.add(const Duration(minutes: 5))), isTrue);
    expect(
      calculator.compatible(
        a,
        a.add(const Duration(minutes: 5, milliseconds: 1)),
      ),
      isFalse,
    );
  });

  test('manual 1440@20/h is 480/day, 72h, 3.00 days', () {
    final model = calculator.manual(quantity: 1440, rate: 20);
    expect(model.hourlyRate, 20);
    expect(model.dailyRate, 480);
    expect(model.hours, 72);
    expect(model.daysLabel, '3.00');
  });

  test('Q=0 is 0h; R=0 is Not modeled', () {
    expect(calculator.manual(quantity: 0, rate: 20).hours, 0);
    expect(calculator.manual(quantity: 1440, rate: 0).modeled, isFalse);
    expect(calculator.manual(quantity: 1440, rate: 0).hours, isNull);
  });

  test('Calculate does not save; Cancel restores prior 20/h', () {
    final draft = FuelScenarioDraft(savedRate: 20);
    draft.calculate(quantity: 1440, rate: 18);
    expect(draft.savedRate, 20);
    expect(draft.previewRate, 18);
    draft.cancel();
    expect(draft.savedRate, 20);
    expect(draft.previewRate, isNull);
    draft.calculate(quantity: 1440, rate: 18);
    draft.save();
    expect(draft.savedRate, 18);
  });
}
