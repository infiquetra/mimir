// C5 RED: F4 severity boundaries and two-episode rearm sequence.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_alert.dart';
import 'package:mimir/features/corporation/domain/corporation_fuel_calculator.dart';

void main() {
  const calculator = CorporationFuelCalculator();
  const reducer = CorporationFuelAlertReducer();

  test('severity boundaries at 72h, 24h, zero, and missing', () {
    expect(
      calculator.severity(const Duration(hours: 72, milliseconds: 1)),
      'Normal',
    );
    expect(calculator.severity(const Duration(hours: 72)), 'Low');
    expect(
      calculator.severity(const Duration(hours: 24, milliseconds: 1)),
      'Low',
    );
    expect(calculator.severity(const Duration(hours: 24)), 'Critical');
    expect(calculator.severity(const Duration(milliseconds: 1)), 'Critical');
    expect(calculator.severity(Duration.zero), 'Reported expiry passed');
    expect(
      calculator.severity(const Duration(milliseconds: -1)),
      'Reported expiry passed',
    );
    expect(calculator.severity(null), 'Unknown');
  });

  test('F4 sequence 23h→22h→0h→48h→24h yields two episodes', () {
    var state = FuelAlertState();
    for (final remaining in const [
      Duration(hours: 23),
      Duration(hours: 22),
      Duration.zero,
    ]) {
      state = reducer.reduce(state, FuelAlertEvent(remaining: remaining));
    }
    state = reducer.reduce(
      state,
      const FuelAlertEvent(remaining: Duration(hours: 48)),
    );
    state = reducer.reduce(
      state,
      const FuelAlertEvent(remaining: Duration(hours: 24)),
    );
    expect(state.episodes, 2);
  });
}
