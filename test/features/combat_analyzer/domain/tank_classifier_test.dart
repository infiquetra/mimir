import 'package:flutter_test/flutter_test.dart';
import 'package:mimir/features/combat_analyzer/domain/tank_classifier.dart';
import 'package:mimir/features/fitting/domain/models.dart';

void main() {
  group('TankClassifier', () {
    FittingStats stats({
      double shieldEhp = 620.69,
      double armorEhp = 666.67,
      double hullEhp = 522.39,
      double shieldBoost = 0,
      double armorRepair = 0,
      double hullRepair = 0,
    }) {
      return FittingStats(
        defenses: DefenseProfile(
          shieldHp: shieldEhp,
          armorHp: armorEhp,
          hullHp: hullEhp,
          shieldEhp: shieldEhp,
          armorEhp: armorEhp,
          hullEhp: hullEhp,
          effectiveShieldBoost: shieldBoost,
          effectiveArmorRepair: armorRepair,
          effectiveHullRepair: hullRepair,
        ),
      );
    }

    final baseline = stats();

    test('T5.1 LAR + LSE is Armor (active) and names 61.3 HP/s', () {
      final result = TankClassifier.classify(
        fit: stats(armorRepair: 61.33, shieldEhp: 620.69 + 3586),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.armor);
      expect(result.mode, TankMode.active);
      expect(result.reasoning, contains('61.3 HP/s'));
    });

    test('T5.2 2x MSE is Shield (buffer)', () {
      final result = TankClassifier.classify(
        fit: stats(shieldEhp: 620.69 + 3034.5),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.shield);
      expect(result.mode, TankMode.buffer);
    });

    test('T5.3 small shield booster is Shield (active)', () {
      final result = TankClassifier.classify(
        fit: stats(shieldBoost: 17.5),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.shield);
      expect(result.mode, TankMode.active);
    });

    test('T5.4 LAR + MSB prefers armor active and names both rates', () {
      final result = TankClassifier.classify(
        fit: stats(armorRepair: 61.33, shieldBoost: 34.67),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.armor);
      expect(result.mode, TankMode.active);
      expect(result.reasoning, contains('61.3'));
      expect(result.reasoning, contains('34.7'));
    });

    test('T5.5 bulkheads-only is Hull (buffer)', () {
      final result = TankClassifier.classify(
        fit: stats(hullEhp: 522.39 + 130.6),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.hull);
      expect(result.mode, TankMode.buffer);
    });

    test('T5.8 reasoning is non-empty and label is Armor (active)', () {
      final result = TankClassifier.classify(
        fit: stats(armorRepair: 61.33, shieldEhp: 620.69 + 3586),
        baseline: baseline,
      );
      expect(result.reasoning, isNotEmpty);
      expect(result.label, 'Armor (active)');
    });

    test('T5.9 DCU-only Rifter is Hull (buffer) — documented edge', () {
      final result = TankClassifier.classify(
        fit: stats(
          shieldEhp: 620.69 + 88.7,
          armorEhp: 666.67 + 117.6,
          hullEhp: 522.39 + 348.3,
        ),
        baseline: baseline,
      );
      expect(result.layer, TankLayer.hull);
      expect(result.mode, TankMode.buffer);
    });

    test('E.10 bare hull with armor EHP largest is Armor (unfitted)', () {
      final result = TankClassifier.classify(fit: baseline, baseline: baseline);
      expect(result.layer, TankLayer.armor);
      expect(result.mode, TankMode.unfitted);
    });

    test('E.11 active HP/s tie breaks by armor EHP then fixed order armor', () {
      final armorWins = TankClassifier.classify(
        fit: stats(
          shieldBoost: 20,
          armorRepair: 20,
          armorEhp: 800,
          shieldEhp: 400,
        ),
        baseline: baseline,
      );
      expect(armorWins.layer, TankLayer.armor);
      expect(armorWins.mode, TankMode.active);

      final equalEhp = TankClassifier.classify(
        fit: stats(
          shieldBoost: 20,
          armorRepair: 20,
          armorEhp: 500,
          shieldEhp: 500,
        ),
        baseline: baseline,
      );
      expect(equalEhp.layer, TankLayer.armor);
    });

    test('E.12 all HP zero is unknown / unfitted', () {
      final empty = stats(shieldEhp: 0, armorEhp: 0, hullEhp: 0);
      final result = TankClassifier.classify(fit: empty, baseline: empty);
      expect(result.layer, TankLayer.unknown);
      expect(result.mode, TankMode.unfitted);
    });
  });
}
