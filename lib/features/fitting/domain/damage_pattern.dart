import '../../../core/logging/logger.dart';
import 'models.dart';

/// Incoming damage split. Fractions are normalised to sum to 1.
class DamagePattern {
  const DamagePattern({
    required this.em,
    required this.thermal,
    required this.kinetic,
    required this.explosive,
    this.label = 'omni',
  });

  final double em;
  final double thermal;
  final double kinetic;
  final double explosive;
  final String label;

  static const omni = DamagePattern(
    em: 0.25,
    thermal: 0.25,
    kinetic: 0.25,
    explosive: 0.25,
  );

  /// Normalises raw amounts; returns null when the total is 0.
  static DamagePattern? fromAmounts({
    required double em,
    required double thermal,
    required double kinetic,
    required double explosive,
    String label = 'observed',
  }) {
    final total = em + thermal + kinetic + explosive;
    if (total <= 0) {
      Log.d('FITTING', 'DamagePattern.fromAmounts total=$total -> null');
      return null;
    }
    final pattern = DamagePattern(
      em: em / total,
      thermal: thermal / total,
      kinetic: kinetic / total,
      explosive: explosive / total,
      label: label,
    );
    Log.d(
      'FITTING',
      'DamagePattern.fromAmounts $label '
          'em=${pattern.em.toStringAsFixed(3)} '
          'th=${pattern.thermal.toStringAsFixed(3)} '
          'kin=${pattern.kinetic.toStringAsFixed(3)} '
          'exp=${pattern.explosive.toStringAsFixed(3)}',
    );
    return pattern;
  }
}

class LayeredEhp {
  const LayeredEhp({
    required this.pattern,
    required this.shield,
    required this.armor,
    required this.hull,
  });

  final DamagePattern pattern;
  final double shield;
  final double armor;
  final double hull;

  double get total => shield + armor + hull;
}

extension DefenseProfileEhp on DefenseProfile {
  /// pyfa `calculateEhp`: hp / Σ_t p_t · resonance_t, per layer.
  LayeredEhp ehpAgainst(DamagePattern p) {
    final layered = LayeredEhp(
      pattern: p,
      shield: _layerEhp(shieldHp, shieldResists, p),
      armor: _layerEhp(armorHp, armorResists, p),
      hull: _layerEhp(hullHp, hullResists, p),
    );
    Log.d(
      'FITTING',
      'ehpAgainst(${p.label}) shield=${layered.shield.toStringAsFixed(1)} '
          'armor=${layered.armor.toStringAsFixed(1)} '
          'hull=${layered.hull.toStringAsFixed(1)} '
          'total=${layered.total.toStringAsFixed(1)}',
    );
    return layered;
  }
}

double _layerEhp(double hp, ResistProfile r, DamagePattern p) {
  final denom =
      p.em * (1 - r.em / 100) +
      p.thermal * (1 - r.thermal / 100) +
      p.kinetic * (1 - r.kinetic / 100) +
      p.explosive * (1 - r.explosive / 100);
  return denom <= 0 ? hp : hp / denom;
}
