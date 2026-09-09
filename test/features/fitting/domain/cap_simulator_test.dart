import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/fitting/domain/cap_simulator.dart';

void main() {
  group('CapSimulator', () {
    test('no drains is fully stable', () {
      final result = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [],
      ).run();

      expect(result.isStable, isTrue);
      expect(result.stablePercent, closeTo(100, 0.001));
    });

    test('light drain settles high', () {
      // 10 GJ every 10s = 1 GJ/s against a peak recharge of
      // 2.5 * 1000 / 60 = 41.7 GJ/s.
      final result = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [CapDrain(durationMs: 10000, capNeed: 10)],
      ).run();

      expect(result.isStable, isTrue);
      expect(result.stablePercent, greaterThan(80));
      expect(result.stablePercent, lessThanOrEqualTo(100));
    });

    test('overwhelming drain empties the capacitor', () {
      final result = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [CapDrain(durationMs: 1000, capNeed: 1000)],
      ).run();

      expect(result.isStable, isFalse);
      expect(result.secondsToEmpty, greaterThan(0));
      expect(result.secondsToEmpty, lessThan(60));
    });

    test('staggered identical modules match a halved cycle', () {
      final staggered = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [CapDrain(durationMs: 10000, capNeed: 20, count: 2)],
      ).run();
      final halved = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [CapDrain(durationMs: 5000, capNeed: 20)],
      ).run();

      expect(staggered.isStable, halved.isStable);
      expect(staggered.stablePercent, closeTo(halved.stablePercent, 0.001));
    });

    test('stability falls as drain rises', () {
      double stablePercentFor(double capNeed) => CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: [CapDrain(durationMs: 5000, capNeed: capNeed)],
      ).run().stablePercent;

      final light = stablePercentFor(20);
      final medium = stablePercentFor(60);
      final heavy = stablePercentFor(120);

      expect(light, greaterThan(medium));
      expect(medium, greaterThan(heavy));
    });

    test('cap injectors stabilize an overwhelming drain', () {
      // 60 GJ/s exceeds the peak recharge (0.5 * 1000 / 12s = 41.7 GJ/s),
      // so alone the capacitor empties; a 400 GJ booster every 10s adds
      // 40 GJ/s on demand and closes the gap.
      const drain = CapDrain(durationMs: 1000, capNeed: 60);
      final alone = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [drain],
      ).run();
      final boosted = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [drain],
        injectors: const [CapInjector(durationMs: 10000, capGain: 400)],
      ).run();

      expect(alone.isStable, isFalse);
      expect(boosted.isStable, isTrue);
    });

    test('boosters alone leave the capacitor full', () {
      final result = CapSimulator(
        capacity: 1000,
        rechargeMs: 60000,
        drains: const [],
        injectors: const [CapInjector(durationMs: 10000, capGain: 400)],
      ).run();

      expect(result.isStable, isTrue);
      expect(result.stablePercent, closeTo(100, 0.001));
    });
  });
}
