import 'models.dart';

/// Incoming damage split. Fractions are normalised to sum to 1.
///
/// Stub for U0 tests (design §2.4). Devs own the engine wiring that feeds
/// [DefenseProfile] EHP fields from `ehpAgainst(DamagePattern.omni)`.
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
    if (total == 0) return null;
    return DamagePattern(
      em: em / total,
      thermal: thermal / total,
      kinetic: kinetic / total,
      explosive: explosive / total,
      label: label,
    );
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
  LayeredEhp ehpAgainst(DamagePattern p) => LayeredEhp(
    pattern: p,
    shield: _layerEhp(shieldHp, shieldResists, p),
    armor: _layerEhp(armorHp, armorResists, p),
    hull: _layerEhp(hullHp, hullResists, p),
  );
}

double _layerEhp(double hp, ResistProfile r, DamagePattern p) {
  final denom =
      p.em * (1 - r.em / 100) +
      p.thermal * (1 - r.thermal / 100) +
      p.kinetic * (1 - r.kinetic / 100) +
      p.explosive * (1 - r.explosive / 100);
  return denom <= 0 ? hp : hp / denom;
}
